import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> requireRtcPermission({required bool camera}) async {
  final permission = camera ? Permission.camera : Permission.microphone;
  if (!await permission.isGranted && !await permission.request().isGranted) {
    throw StateError('Permission denied');
  }
}

class RtcDirectory extends ChangeNotifier {
  RtcDirectory(this.userId);

  final String userId;
  final SupabaseClient client = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  int _generation = 0;
  bool _closed = false;
  List<Map<String, dynamic>> sessions = [];
  String? error;

  void start() {
    final channel = client.channel('toti-rtc-$userId');
    _channel = channel;
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rtc_sessions',
          callback: (_) => unawaited(refresh()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rtc_sessions',
          callback: (_) => unawaited(refresh()),
        )
        .subscribe((status, [failure]) {
          if (!_closed && status == RealtimeSubscribeStatus.subscribed) {
            unawaited(refresh());
          }
        });
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_closed || client.auth.currentUser?.id != userId) return;
    final generation = ++_generation;
    try {
      final result = await client
          .from('rtc_sessions')
          .select()
          .inFilter('status', ['preparing', 'ringing', 'active'])
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
      if (_closed ||
          generation != _generation ||
          client.auth.currentUser?.id != userId)
        return;
      sessions = result.map((row) => Map<String, dynamic>.from(row)).toList();
      error = null;
      notifyListeners();
    } catch (_) {
      if (_closed || generation != _generation) return;
      error = 'Could not load real-time sessions.';
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> startSession({
    required String kind,
    String title = '',
    String? peerId,
    String summary = '',
    String tag = '',
  }) async {
    final result = await client
        .rpc(
          'start_toti_rtc',
          params: {
            'p_kind': kind,
            'p_title': title,
            'p_peer': peerId,
            'p_summary': summary,
            'p_tag': tag,
          },
        )
        .timeout(const Duration(seconds: 15));
    final row = result is List && result.length == 1 ? result.single : result;
    if (row is! Map) throw StateError('Session unavailable');
    await refresh();
    return Map<String, dynamic>.from(row);
  }

  Future<void> update(String id, String action) async {
    await client
        .rpc('update_toti_rtc', params: {'p_id': id, 'p_action': action})
        .timeout(const Duration(seconds: 15));
    await refresh();
  }

  Map<String, dynamic>? session(String id) {
    for (final value in sessions) {
      if (value['id'] == id) return value;
    }
    return null;
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    _refreshTimer?.cancel();
    if (_channel != null) unawaited(client.removeChannel(_channel!));
    super.dispose();
  }
}

class RtcConnection extends ChangeNotifier {
  RtcConnection(this.sessionId);

  final String sessionId;
  lk.Room? room;
  lk.EventsListener<lk.RoomEvent>? _events;
  final List<({String author, String text})> messages = [];
  bool _closed = false;
  int _generation = 0;

  Future<void> connect({required bool microphone, required bool camera}) async {
    final generation = ++_generation;
    if (microphone) await requireRtcPermission(camera: false);
    if (camera) await requireRtcPermission(camera: true);
    if (_closed || generation != _generation) return;
    final response = await Supabase.instance.client.functions
        .invoke('rtc-token', body: {'sessionId': sessionId})
        .timeout(const Duration(seconds: 20));
    final data = response.data;
    if (response.status != 200 ||
        data is! Map ||
        data['url'] is! String ||
        data['token'] is! String) {
      throw StateError('Unable to join session');
    }
    if (_closed || generation != _generation) return;
    final next = lk.Room(
      roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
    );
    room = next;
    next.addListener(_changed);
    _events = next.createListener()
      ..on<lk.DataReceivedEvent>((event) {
        if (_closed ||
            event.topic != 'toti-chat' ||
            event.participant == null ||
            event.data.length > 2000)
          return;
        try {
          final data = jsonDecode(utf8.decode(event.data));
          if (data is! Map || data['text'] is! String) return;
          final text = (data['text'] as String).trim();
          if (text.isEmpty || text.length > 300) return;
          _addMessage(event.participant!.identity, text);
        } catch (_) {
          // Ignore malformed data from a room participant.
        }
      });
    try {
      await next
          .connect(data['url'] as String, data['token'] as String)
          .timeout(const Duration(seconds: 30));
      if (_closed || generation != _generation) return;
      if (microphone) await next.localParticipant?.setMicrophoneEnabled(true);
      if (camera) await next.localParticipant?.setCameraEnabled(true);
      _changed();
    } catch (_) {
      if (room == next) await disconnect();
      rethrow;
    }
  }

  void _changed() {
    if (!_closed) notifyListeners();
  }

  void _addMessage(String author, String text) {
    messages.add((author: author, text: text));
    if (messages.length > 50) messages.removeAt(0);
    _changed();
  }

  Future<void> sendMessage(String text) async {
    final value = text.trim();
    final participant = room?.localParticipant;
    if (participant == null || value.isEmpty || value.length > 300) {
      throw StateError('Message unavailable');
    }
    await participant.publishData(
      utf8.encode(jsonEncode({'text': value})),
      reliable: true,
      topic: 'toti-chat',
    );
    _addMessage(participant.identity, value);
  }

  lk.VideoTrack? get localVideo {
    for (final publication
        in room?.localParticipant?.videoTrackPublications ?? []) {
      if (publication.track != null && !publication.muted)
        return publication.track;
    }
    return null;
  }

  lk.VideoTrack? get remoteVideo {
    for (final participant
        in room?.remoteParticipants.values ?? <lk.RemoteParticipant>[]) {
      for (final publication in participant.videoTrackPublications) {
        if (publication.track != null && !publication.muted)
          return publication.track;
      }
    }
    return null;
  }

  Future<void> disconnect() async {
    _generation++;
    final events = _events;
    _events = null;
    if (events != null) await events.dispose();
    final current = room;
    room = null;
    if (current != null) {
      current.removeListener(_changed);
      try {
        await current.disconnect();
      } finally {
        await current.dispose();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(disconnect().catchError((_) {}));
    super.dispose();
  }
}
