import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Member {
  final int index;
  final String name, country, image, bio, region, doorway;
  final List<String> interests;
  Member(
    this.index,
    this.name,
    this.country,
    this.image,
    this.bio,
    this.region,
    this.doorway,
    this.interests,
  );
  String get id => 'member-$index';
  bool get live => index % 3 != 1;
  int get age => 22 + index % 12;
}

class AppStore extends ChangeNotifier {
  late SharedPreferences prefs;
  late Map<String, dynamic> data;
  late Map<String, dynamic> translations;
  late List<Member> members;
  Map<String, dynamic> state = {};
  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    data = jsonDecode(
      await rootBundle.loadString('assets/data/community.json'),
    );
    translations = jsonDecode(
      await rootBundle.loadString('assets/data/translations.json'),
    );
    try {
      state = jsonDecode(prefs.getString('lookme_state') ?? '{}');
    } catch (_) {
      state = {};
    }
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
    if (get('signedIn', false) == true) login();
  }

  dynamic get(String key, dynamic fallback) => state[key] ?? fallback;
  List<String> list(String key) => List<String>.from(get(key, []));
  List<Map<String, dynamic>> records(String key) =>
      (get(key, []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  void put(String key, dynamic value) {
    state[key] = value;
    save();
  }

  void save() {
    prefs.setString('lookme_state', jsonEncode(state));
    notifyListeners();
  }

  void toggle(String key, String value) {
    final l = list(key);
    l.contains(value) ? l.remove(value) : l.add(value);
    put(key, l);
  }

  bool mutual(Member m) =>
      list('following').contains(m.id) &&
      list('followers').contains(m.id) &&
      !list('blocked').contains(m.id);
  void login() {
    state['signedIn'] = true;
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
    for (var i = 0; i < plan.length; i++) {
      Future.delayed(Duration(seconds: 4 + i * 7), () {
        if (get('signedIn', false) != true ||
            list('blocked').contains(plan[i])) {
          return;
        }
        final followers = list('followers');
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
    final items = records(key);
    items.insert(0, record);
    put(key, items);
  }

  void block(Member m) {
    final blocked = list('blocked');
    if (!blocked.contains(m.id)) blocked.add(m.id);
    state['blocked'] = blocked;
    state['following'] = list('following')..remove(m.id);
    state['followers'] = list('followers')..remove(m.id);
    save();
  }

  void clear() {
    state = {};
    save();
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
