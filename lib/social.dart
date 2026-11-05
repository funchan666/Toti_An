import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud.dart';

/// Real account interactions. Editorial profiles are intentionally separate.
class SocialStore extends ChangeNotifier {
  final String userId;
  final SupabaseClient client = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _avatarRefresh;
  int _generation = 0;
  bool _closed = false;
  bool connected = false;
  String? error;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> comments = [];
  Set<String> following = {};
  Set<String> followers = {};
  Set<String> blocked = {};
  Set<String> likes = {};

  SocialStore(this.userId);

  void start() {
    _scheduleAvatarRefresh();
    final channel = client.channel('toti-social-$userId');
    _channel = channel;
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_follows',
          callback: (_) => unawaited(refresh()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_follows',
          callback: (_) => unawaited(refresh()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          callback: (_) => unawaited(refresh()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'content_comments',
          callback: (_) => unawaited(refresh()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'content_likes',
          callback: (_) => unawaited(refresh()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'content_likes',
          callback: (_) => unawaited(refresh()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'directory_revision',
          callback: (_) => unawaited(refresh()),
        )
        .subscribe((status, [failure]) {
          if (_closed || _channel != channel) return;
          connected = status == RealtimeSubscribeStatus.subscribed;
          if (connected) {
            unawaited(refresh());
          } else {
            _generation++;
            _clearRemote();
            error = 'Connection unavailable. Tap to retry.';
            notifyListeners();
          }
        });
  }

  void _scheduleAvatarRefresh() {
    _avatarRefresh ??= Timer.periodic(
      const Duration(minutes: 4),
      (_) => unawaited(refresh()),
    );
  }

  void pause() {
    _avatarRefresh?.cancel();
    _avatarRefresh = null;
  }

  void resume() {
    if (_closed) return;
    _scheduleAvatarRefresh();
    unawaited(refresh());
  }

  Future<void> retry() async {
    if (_closed) return;
    if (connected) return refresh();
    final old = _channel;
    _channel = null;
    if (old != null) await client.removeChannel(old);
    if (!_closed) start();
  }

  Future<void> refresh() async {
    if (_closed || client.auth.currentUser?.id != userId) return;
    final request = ++_generation;
    try {
      final result = await Future.wait<dynamic>([
        client.rpc('discover_toti_users'),
        client.from('user_follows').select(),
        client.from('user_blocks').select(),
        _readRows('direct_messages'),
        client.rpc('discover_toti_avatars'),
        _readRows('content_comments'),
        client.from('content_likes').select(),
      ]).timeout(const Duration(seconds: 20));
      final urls = <String, String>{};
      await Future.wait(
        (result[4] as List).map((row) async {
          try {
            urls[row['user_id'] as String] = await TotiCloud.avatarUrl(
              row['avatar_key'] as String,
            ).timeout(const Duration(seconds: 8));
          } catch (_) {
            // A missing avatar must not hide the rest of the directory.
          }
        }),
      );
      if (_closed ||
          request != _generation ||
          client.auth.currentUser?.id != userId)
        return;
      final edges = (result[1] as List).cast<Map<String, dynamic>>();
      users = [
        for (final row in (result[0] as List))
          {
            ...Map<String, dynamic>.from(row),
            'avatar_url': urls[row['user_id']],
          },
      ];
      following = {
        for (final row in edges)
          if (row['active'] == true && row['follower_id'] == userId)
            row['followee_id'] as String,
      };
      followers = {
        for (final row in edges)
          if (row['active'] == true && row['followee_id'] == userId)
            row['follower_id'] as String,
      };
      blocked = {
        for (final row in (result[2] as List)) row['blocked_id'] as String,
      };
      messages = (result[3] as List).cast<Map<String, dynamic>>();
      comments = (result[5] as List).cast<Map<String, dynamic>>();
      likes = {
        for (final row in (result[6] as List))
          if (row['active'] == true) row['content_id'] as String,
      };
      error = connected ? null : 'Connection unavailable. Tap to retry.';
      notifyListeners();
    } catch (_) {
      if (!_closed && request == _generation) {
        _clearRemote();
        error = 'Could not load community data. Tap to retry.';
        notifyListeners();
      }
    }
  }

  void _clearRemote() {
    users = [];
    messages = [];
    comments = [];
    following = {};
    followers = {};
    blocked = {};
    likes = {};
  }

  Future<List<Map<String, dynamic>>> _readRows(String table) async {
    final result = <Map<String, dynamic>>[];
    const pageSize = 200;
    for (var offset = 0; ; offset += pageSize) {
      final page = await client
          .from(table)
          .select()
          .order('created_at')
          .order('id')
          .range(offset, offset + pageSize - 1);
      result.addAll(page);
      if (page.length < pageSize) return result;
    }
  }

  Future<void> toggleFollow(String other) async {
    await client.from('user_follows').upsert({
      'follower_id': userId,
      'followee_id': other,
      'active': !following.contains(other),
    });
    await refresh();
  }

  Future<void> block(String other) async {
    await client.rpc('block_toti_user', params: {'p_user': other});
    await refresh();
  }

  Future<void> unblock(String other) async {
    await client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', userId)
        .eq('blocked_id', other);
    await refresh();
  }

  Future<void> send(String other, String body, String clientId) async {
    await client.rpc(
      'send_toti_message',
      params: {'p_recipient': other, 'p_body': body, 'p_client_id': clientId},
    );
    unawaited(refresh());
  }

  Future<void> sendComment(String content, String body, String clientId) async {
    await client.rpc(
      'send_toti_comment',
      params: {'p_content': content, 'p_body': body, 'p_client_id': clientId},
    );
    unawaited(refresh());
  }

  Future<void> setLike(String content, bool active) async {
    await client.from('content_likes').upsert({
      'user_id': userId,
      'content_id': content,
      'active': active,
    });
    await refresh();
  }

  Future<void> importLegacyLikes(List<String> contents) async {
    if (contents.isEmpty) return;
    await client
        .from('content_likes')
        .upsert(
          [
            for (final content in contents)
              {'user_id': userId, 'content_id': content, 'active': true},
          ],
          onConflict: 'user_id,content_id',
          ignoreDuplicates: true,
        );
  }

  static String newMessageId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  void dispose() {
    _closed = true;
    pause();
    _generation++;
    final channel = _channel;
    if (channel != null) unawaited(client.removeChannel(channel));
    super.dispose();
  }
}
