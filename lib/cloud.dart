import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

const totiSupabaseUrl = 'https://zmtihifixkymzcicbswh.supabase.co';
const totiPublishableKey = 'sb_publishable_DcU6LXJ4GGGjL2ohUj7U_g_gooYz1Xb';

class TotiCloud {
  static Future<void>? _pendingDeletion;
  static String? _deletingUserId;
  static String? _confirmedDeletedUserId;
  static String? _avatarCacheOwner;
  static final Map<String, (DateTime, Future<String>)> _avatarUrls = {};

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: totiSupabaseUrl,
      publishableKey: totiPublishableKey,
    );
  }

  static String? get currentUserId {
    final user = Supabase.instance.client.auth.currentUser;
    return user == null || user.isAnonymous ? null : user.id;
  }

  static Uri mediaUrl(String path) => Uri.parse(
    '$totiSupabaseUrl/storage/v1/object/public/toti-editorial/$path',
  );

  static Future<String?> register(String email, String password) async {
    final result = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
    return result.session?.user.id;
  }

  static Future<String> signIn(String email, String password) async {
    final result = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final session = result.session;
    if (session == null || session.user.isAnonymous) {
      throw StateError('No email account session was returned');
    }
    return session.user.id;
  }

  static Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  static Future<void> submitReport(
    String target,
    String? subject,
    String reason,
  ) async {
    final client = Supabase.instance.client;
    final userId = currentUserId;
    if (userId == null) throw StateError('No account session');
    await client.from('content_reports').insert({
      'reporter_id': userId,
      'target_id': target,
      'subject_id': subject,
      'reason': reason,
    });
  }

  static Future<void> deleteAccount(String userId) async {
    if (_confirmedDeletedUserId == userId) return;
    if (currentUserId != userId) throw StateError('No account session');
    if (_pendingDeletion != null && _deletingUserId != userId) {
      throw StateError('Another account deletion is pending');
    }
    _deletingUserId = userId;
    final attempt = _pendingDeletion ??= _deleteAccount().whenComplete(() {
      _pendingDeletion = null;
      _deletingUserId = null;
    });
    await attempt.timeout(const Duration(seconds: 20));
  }

  static Future<Map<String, dynamic>?> readProfile() async {
    final client = Supabase.instance.client;
    final session = await client.auth.getSession();
    if (session == null) throw StateError('No account session');
    return await client
        .from('user_profiles')
        .select('nickname,gender,birthday,country,avatar_key')
        .eq('user_id', session.user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
  }

  static Future<String> uploadAvatar(Uint8List bytes, String mime) async {
    final client = Supabase.instance.client;
    final userId = currentUserId;
    if (userId == null) throw StateError('No account session');
    final random = Random.secure();
    final name = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final path = '$userId/$name';
    await client.storage
        .from('toti-avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    return path;
  }

  static Future<String> avatarUrl(String path) {
    final owner = currentUserId;
    if (owner == null) return Future.error(StateError('No account session'));
    if (_avatarCacheOwner != owner) {
      _avatarUrls.clear();
      _avatarCacheOwner = owner;
    }
    final cached = _avatarUrls[path];
    if (cached != null && cached.$1.isAfter(DateTime.now())) return cached.$2;
    Future<String> fetch() async {
      try {
        return await Supabase.instance.client.storage
            .from('toti-avatars')
            .createSignedUrl(path, 300);
      } catch (_) {
        _avatarUrls.remove(path);
        rethrow;
      }
    }

    final future = fetch();
    _avatarUrls[path] = (
      DateTime.now().add(const Duration(minutes: 3)),
      future,
    );
    return future;
  }

  static Future<Map<String, dynamic>> saveProfile(
    Map<String, dynamic> profile,
  ) async {
    final client = Supabase.instance.client;
    final session = await client.auth.getSession();
    if (session == null) throw StateError('No account session');
    return await client
        .from('user_profiles')
        .upsert({'user_id': session.user.id, ...profile})
        .select('nickname,gender,birthday,country,avatar_key')
        .single()
        .timeout(const Duration(seconds: 20));
  }

  static Future<Map<String, dynamic>?> createLegacyProfile(
    Map<String, dynamic> profile,
  ) async {
    final client = Supabase.instance.client;
    final session = await client.auth.getSession();
    if (session == null) throw StateError('No account session');
    try {
      return await client
          .from('user_profiles')
          .insert({'user_id': session.user.id, ...profile})
          .select('nickname,gender,birthday,country,avatar_key')
          .single();
    } on PostgrestException catch (error) {
      if (error.code == '23505') return readProfile();
      rethrow;
    }
  }

  static Future<void> _deleteAccount() async {
    final client = Supabase.instance.client;
    final session = await client.auth.getSession();
    if (session == null || session.user.id != _deletingUserId) {
      throw StateError('No account session');
    }
    final response = await client.functions.invoke('delete-account', body: {});
    if (response.data is! Map || response.data['deleted'] != true) {
      throw StateError('Account deletion was not confirmed');
    }
    _confirmedDeletedUserId = session.user.id;
    if (client.auth.currentUser?.id != session.user.id) return;
    try {
      await client.auth.signOut();
    } catch (_) {
      // The server already deleted this identity; the SDK clears local state first.
    }
  }

  static Future<Map<String, dynamic>> readCommunity() async {
    final client = Supabase.instance.client;
    final results = await Future.wait([
      client.from('editorial_catalog').select().order('sort_index'),
      client.from('editorial_reels').select().order('original_index'),
      client.from('editorial_comments').select().order('sort_index'),
      client.from('editorial_rooms').select().order('sort_index'),
      client.from('editorial_moments').select().order('sort_index'),
    ]).timeout(const Duration(seconds: 20));
    final result = <String, dynamic>{};
    for (final row in results[0]) {
      final name = row['category'] as String;
      final values = result.putIfAbsent(name, () => <dynamic>[]) as List;
      values.add(row['content']);
    }
    result['reels'] = [
      for (final row in results[1])
        {
          'video': (row['video_key'] as String).substring(
            'assets/videos/'.length,
          ),
          'thumbnail': (row['thumbnail_key'] as String).substring(
            'assets/portraits/'.length,
          ),
          'caption': row['caption'],
        },
    ];
    result['reelComments'] = [
      for (final row in results[2])
        {
          'content': row['content_id'],
          'member': row['author_id'],
          'text': row['body'],
        },
    ];
    result['editorialRooms'] = [for (final row in results[3]) row['content']];
    result['editorialMoments'] = [for (final row in results[4]) row['content']];
    const minimumKeys = [
      'names',
      'countries',
      'images',
      'profileNotes',
      'interestCatalog',
      'doorways',
      'liveVideos',
      'reels',
      'reelComments',
      'editorialRooms',
      'editorialMoments',
    ];
    if (minimumKeys.any(
          (key) => result[key] is! List || (result[key] as List).isEmpty,
        ) ||
        (result['names'] as List).length < (result['images'] as List).length ||
        (result['countries'] as List).length <
            (result['images'] as List).length ||
        (result['profileNotes'] as List).length < 12 ||
        (result['doorways'] as List).length < 6 ||
        (result['liveVideos'] as List).length < 9 ||
        (result['reels'] as List).length > (result['images'] as List).length) {
      throw StateError('Community data is incomplete');
    }
    return result;
  }
}
