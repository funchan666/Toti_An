import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud.dart';
import 'social.dart';

class Member {
  final int index;
  final String name, country, image, bio, region, doorway;
  final List<String> interests;
  final String? authId;
  final int? realAge;
  Member(
    this.index,
    this.name,
    this.country,
    this.image,
    this.bio,
    this.region,
    this.doorway,
    this.interests, {
    this.authId,
    this.realAge,
  });
  String get id => authId == null ? 'member-$index' : 'user:$authId';
  bool get live => authId == null && index % 3 != 1;
  int get age => realAge ?? 22 + index % 12;
}

class AppStore extends ChangeNotifier with WidgetsBindingObserver {
  late SharedPreferences prefs;
  late Map<String, dynamic> data;
  late Map<String, dynamic> translations;
  List<Member> members = [];
  Map<String, dynamic> state = {};
  String? activeUserId;
  bool cloudContentLoaded = false;
  SocialStore? social;
  bool _legacyMigrationRunning = false;
  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    WidgetsBinding.instance.addObserver(this);
    data = jsonDecode(
      await rootBundle.loadString('assets/data/community.json'),
    );
    translations = jsonDecode(
      await rootBundle.loadString('assets/data/translations.json'),
    );
    activeUserId = TotiCloud.currentUserId;
    state = _loadAccountState(activeUserId);
    if (activeUserId != null && get('signedIn', false) == true) {
      await refreshCloudContent();
    }
    _buildMembers();
    if (activeUserId != null) _installSeedComments();
    if (get('signedIn', false) == true && activeUserId != null) {
      try {
        await restoreCloudProfile();
      } catch (_) {
        // Keep existing device data until the cloud profile can be read.
      }
      login();
    }
  }

  Future<void> refreshCloudContent() async {
    try {
      data = await TotiCloud.readCommunity();
      cloudContentLoaded = true;
      _buildMembers();
    } catch (_) {
      // Preserve the current experience while the A-stage migration is incomplete.
    }
  }

  void _buildMembers() {
    final images = data['images'] as List;
    final countries = data['countries'] as List;
    members = List.generate(images.length, (i) {
      final flag = countries[i] as String;
      String region = 'Global';
      if (['🇺🇸', '🇨🇦'].contains(flag)) region = 'North America';
      if ([
        '🇪🇸',
        '🇩🇪',
        '🇫🇷',
        '🇬🇧',
        '🇮🇹',
        '🇳🇴',
        '🇨🇿',
        '🇳🇱',
        '🇵🇹',
        '🇮🇪',
        '🇮🇸',
        '🇨🇭',
        '🇧🇪',
      ].contains(flag)) {
        region = 'Europe';
      }
      if (['🇯🇵', '🇸🇬', '🇰🇷', '🇨🇳', '🇵🇭'].contains(flag)) {
        region = 'Asia';
      }
      if (flag == '🇮🇳') region = 'India';
      if (['🇧🇷', '🇲🇽'].contains(flag)) region = 'Latin';
      if (flag == '🇲🇦') region = 'MENA';
      if (['🇿🇦', '🇳🇬'].contains(flag)) region = 'Africa';
      if (['🇦🇺', '🇳🇿'].contains(flag)) region = 'Oceania';
      final interests = data['interestCatalog'] as List;
      return Member(
        i,
        data['names'][i],
        flag,
        images[i],
        data['profileNotes'][i % 12],
        region,
        data['doorways'][i % 6],
        [
          for (final n in [i, i + 3, i + 7])
            interests[n % interests.length] as String,
        ],
      );
    });
  }

  Map<String, dynamic> _loadAccountState(String? userId) {
    if (userId == null) return {};
    try {
      return Map<String, dynamic>.from(
        jsonDecode(prefs.getString('toti_user_$userId') ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> activateAccount(String userId) async {
    activeUserId = userId;
    final accountKey = 'toti_user_$userId';
    final existing = prefs.getString(accountKey);
    final legacy = prefs.getString('lookme_state');
    var legacyOwner = prefs.getString('toti_legacy_owner');
    if (existing == null &&
        legacy != null &&
        (legacyOwner == null || legacyOwner == userId)) {
      if (legacyOwner == null) {
        if (!await prefs.setString('toti_legacy_owner', userId)) {
          throw StateError('Could not reserve the existing data');
        }
        legacyOwner = userId;
      }
      try {
        state = Map<String, dynamic>.from(jsonDecode(legacy) as Map);
      } catch (_) {
        throw StateError('Existing account data could not be read');
      }
      state['signedIn'] = false;
      if (!await prefs.setString(accountKey, jsonEncode(state))) {
        throw StateError('Could not preserve existing account data');
      }
    } else {
      state = _loadAccountState(userId);
    }
    state['signedIn'] = false;
    _installSeedComments();
  }

  void _installSeedComments() {
    if (state['seedCommentsInstalled'] != true) {
      final comments = records('comments');
      for (final item in data['reelComments'] as List) {
        final m = members.firstWhere((m) => m.id == item['member']);
        comments.add({
          'content': item['content'],
          'author': m.name,
          'member': m.id,
          'text': item['text'],
        });
      }
      state['comments'] = comments;
      state['seedCommentsInstalled'] = true;
      save();
    }
  }

  dynamic get(String key, dynamic fallback) => state[key] ?? fallback;
  List<String> list(String key) {
    final items = List<String>.from(get(key, []));
    final remote = social;
    if (remote == null) return items;
    if (key == 'likes') return {...items, ...remote.likes}.toList();
    final values = switch (key) {
      'following' => remote.following,
      'followers' => remote.followers,
      'blocked' => remote.blocked,
      _ => <String>{},
    };
    return {...items, for (final id in values) 'user:$id'}.toList();
  }

  List<Map<String, dynamic>> records(String key) {
    final local = (get(key, []) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (social == null) return local;
    final remote = social!;
    if (key == 'comments') {
      return [
        for (final row in remote.comments.reversed)
          {
            'content': row['content_id'],
            'id': row['id'],
            'member': row['author_id'] == remote.userId
                ? null
                : 'user:${row['author_id']}',
            'author': row['author_id'] == remote.userId
                ? get('nickname', 'You')
                : members
                          .where((m) => m.authId == row['author_id'])
                          .map((m) => m.name)
                          .firstOrNull ??
                      'Member',
            'text': row['body'],
          },
        ...local,
      ];
    }
    if (key != 'messages') return local;
    return [
      for (final row in remote.messages.reversed)
        {
          'member':
              'user:${row['sender_id'] == remote.userId ? row['recipient_id'] : row['sender_id']}',
          'text': row['body'],
          '_mine': row['sender_id'] == remote.userId,
          '_id': row['id'],
        },
      ...local,
    ];
  }

  void put(String key, dynamic value) {
    state[key] = value;
    save();
  }

  void save() {
    final userId = activeUserId;
    if (userId != null) prefs.setString('toti_user_$userId', jsonEncode(state));
    notifyListeners();
  }

  Future<void> restoreCloudProfile() async {
    final account = activeUserId;
    var profile = await TotiCloud.readProfile();
    if (profile == null &&
        account != null &&
        prefs.getString('toti_legacy_owner') == account) {
      final nickname = state['nickname'];
      final gender = state['gender'];
      final birthday = state['birthday'];
      final country = state['country'];
      if (nickname is String &&
          allowed(nickname) &&
          gender is String &&
          gender.isNotEmpty &&
          birthday is String &&
          DateTime.tryParse(birthday) != null &&
          country is String &&
          country.isNotEmpty) {
        String? avatarKey;
        final path = state['avatarPath'];
        if (path is String && path.isNotEmpty) {
          final directory = await getApplicationDocumentsDirectory();
          final prefix = '${directory.path}/toti_avatar_';
          if (path.startsWith(prefix) &&
              !path.substring(prefix.length).contains('/') &&
              await File(path).exists() &&
              await File(path).length() <= 10 * 1024 * 1024) {
            final bytes = await File(path).readAsBytes();
            final mime = lookupMimeType(
              path,
              headerBytes: bytes.take(defaultMagicNumbersMaxLength).toList(),
            );
            if (bytes.length <= 10 * 1024 * 1024 &&
                mime != null &&
                {
                  'image/jpeg',
                  'image/png',
                  'image/webp',
                  'image/gif',
                  'image/heic',
                  'image/heif',
                }.contains(mime)) {
              avatarKey = await TotiCloud.uploadAvatar(bytes, mime);
            }
          }
        }
        if (account != activeUserId) return;
        profile = await TotiCloud.createLegacyProfile({
          'nickname': nickname,
          'gender': gender,
          'birthday': birthday,
          'country': country,
          'avatar_key': avatarKey,
        });
      }
    }
    if (profile == null || account == null || account != activeUserId) return;
    state.addAll(profile);
    save();
  }

  Future<void> toggle(String key, String value) async {
    if (key == 'likes') {
      final remote = social;
      if (remote == null) throw StateError('Not connected');
      final account = activeUserId;
      final desired = !list('likes').contains(value);
      await remote.setLike(value, desired);
      if (account == null || activeUserId != account) return;
      final local = List<String>.from(get('likes', []))..remove(value);
      state['likes'] = local;
      save();
      return;
    }
    if (value.startsWith('user:')) {
      if (social == null) throw StateError('Not connected');
      final other = value.substring(5);
      if (key == 'following') return social!.toggleFollow(other);
      if (key == 'blocked') return social!.unblock(other);
      throw StateError('Unsupported real-account action');
    }
    final l = List<String>.from(get(key, []));
    l.contains(value) ? l.remove(value) : l.add(value);
    put(key, l);
  }

  bool mutual(Member m) =>
      list('following').contains(m.id) &&
      list('followers').contains(m.id) &&
      !list('blocked').contains(m.id);
  void login() {
    state['signedIn'] = true;
    _startSocial();
    if (state['welcome'] != true) {
      state['welcome'] = true;
      state['coins'] = (get('coins', 0) as int) + 888;
    }
    save();
    if (state['followerPlan'] == null) {
      final candidates = [...members]..shuffle();
      state['followerPlan'] = candidates.take(3).map((m) => m.id).toList();
      save();
    }
    final plan = list('followerPlan');
    final account = activeUserId;
    for (var i = 0; i < plan.length; i++) {
      Future.delayed(Duration(seconds: 4 + i * 7), () {
        if (activeUserId != account ||
            get('signedIn', false) != true ||
            list('blocked').contains(plan[i])) {
          return;
        }
        final followers = List<String>.from(get('followers', []));
        if (!followers.contains(plan[i])) {
          followers.add(plan[i]);
          state['followers'] = followers;
          final notices = records('notices');
          notices.insert(0, {
            'member': plan[i],
            'text': 'New follower',
            'read': false,
          });
          state['notices'] = notices;
          save();
        }
      });
    }
  }

  void addRecord(String key, Map<String, dynamic> record) {
    final items = (get(key, []) as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    items.insert(0, record);
    put(key, items);
  }

  Future<void> block(Member m) async {
    if (m.authId != null) {
      final remote = social;
      if (remote == null) throw StateError('Not connected');
      await remote.block(m.authId!);
      return;
    }
    final blocked = List<String>.from(get('blocked', []));
    if (!blocked.contains(m.id)) blocked.add(m.id);
    state['blocked'] = blocked;
    state['following'] = List<String>.from(get('following', []))..remove(m.id);
    state['followers'] = List<String>.from(get('followers', []))..remove(m.id);
    save();
  }

  Future<void> clear() async {
    _stopSocial();
    final userId = activeUserId;
    state = {};
    if (userId != null) {
      await prefs.remove('toti_user_$userId');
      if (prefs.getString('toti_legacy_owner') == userId) {
        await prefs.remove('lookme_state');
        await prefs.remove('toti_legacy_owner');
      }
    }
    activeUserId = null;
    notifyListeners();
  }

  void logout() {
    _stopSocial();
    state['signedIn'] = false;
    save();
    activeUserId = null;
    state = {};
    notifyListeners();
  }

  void _startSocial() {
    final userId = activeUserId;
    if (userId == null || social?.userId == userId) return;
    _stopSocial();
    social = SocialStore(userId)..addListener(_socialChanged);
    social!.start();
  }

  void _socialChanged() {
    final remote = social;
    if (remote == null || remote.userId != activeUserId) return;
    members.removeWhere((member) => member.authId != null);
    for (final row in remote.users) {
      final id = row['user_id'];
      final age = row['age'];
      if (id is! String || age is! int) continue;
      members.add(
        Member(
          -1,
          row['nickname'] as String,
          row['country'] as String,
          (row['avatar_url'] as String?) ?? '__real_user__',
          '',
          'Global',
          '',
          const [],
          authId: id,
          realAge: age,
        ),
      );
    }
    if (remote.connected && !_legacyMigrationRunning) {
      unawaited(_migrateLegacyInteractions(remote));
    }
    notifyListeners();
  }

  Future<void> _migrateLegacyInteractions(SocialStore remote) async {
    final account = activeUserId;
    if (account == null ||
        remote.userId != account ||
        prefs.getString('toti_legacy_owner') != account ||
        (state['legacyLikesMigrated'] == true &&
            state['legacyCommentsMigrated'] == true))
      return;
    _legacyMigrationRunning = true;
    try {
      if (state['legacyLikesMigrated'] != true) {
        final likes = List<String>.from(get('likes', []));
        final valid = likes
            .where((id) => id.isNotEmpty && id.length <= 300)
            .toList();
        await remote.importLegacyLikes(valid);
        if (activeUserId != account || social != remote) return;
        state['likes'] = likes.where((id) => !valid.contains(id)).toList();
        state['legacyLikesMigrated'] = true;
        save();
      }
      if (state['legacyCommentsMigrated'] != true) {
        final local = (get('comments', []) as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final migrated = <String>{};
        for (final row in local) {
          final id = row['id'];
          final content = row['content'];
          final body = row['text'];
          if (row['member'] != null ||
              id is! String ||
              id.length < 9 ||
              id.length > 55 ||
              content is! String ||
              content.isEmpty ||
              content.length > 300 ||
              body is! String ||
              !allowed(body))
            continue;
          await remote.sendComment(content, body, 'legacy-$id');
          if (activeUserId != account || social != remote) return;
          migrated.add(id);
        }
        state['comments'] = local
            .where((row) => !migrated.contains(row['id']))
            .toList();
        state['legacyCommentsMigrated'] = true;
        save();
      }
      await remote.refresh();
    } catch (_) {
      // Keep the original local records; a later connection can resume safely.
    } finally {
      _legacyMigrationRunning = false;
    }
  }

  void _stopSocial() {
    final remote = social;
    social = null;
    if (remote != null) {
      remote.removeListener(_socialChanged);
      remote.dispose();
    }
    members.removeWhere((member) => member.authId != null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      social?.resume();
    } else {
      social?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSocial();
    super.dispose();
  }
}

bool allowed(String value) {
  final t = value.trim().toLowerCase();
  if (t.isEmpty || t.length > 2000) return false;
  const banned = [
    'send nude',
    'send pic naked',
    'explicit photo',
    'sexual service',
    'pay for sex',
    'escort service',
    'meet for sex',
    'kill yourself',
    'go die',
    'i will kill',
    'hurt yourself',
    'you should die',
    'i will hurt',
    'hate speech',
    'subhuman',
    'worthless freak',
    'racial slur',
    'terrorize you',
    'wire me money',
    'send crypto',
    'gift card code',
    'guaranteed profit',
    'investment return',
    'account verification fee',
  ];
  final normalized = t
      .replaceAllMapped(
        RegExp('[013457]'),
        (m) =>
            {'0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't'}[m[0]]!,
      )
      .replaceAll(RegExp(r'[^a-z0-9@+.:/\s-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (banned.any(normalized.contains) ||
      RegExp(r'(.)\1{11,}').hasMatch(normalized)) {
    return false;
  }
  for (final p in [
    r'(?:https?://|www\.)',
    r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}',
    r'(?:\+?\d[\d\s().-]{7,}\d)',
  ]) {
    if (RegExp(p).allMatches(normalized).length > 1) return false;
  }
  return true;
}
