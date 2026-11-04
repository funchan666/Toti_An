import 'dart:io';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:record/record.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'store.dart';

const bg = Color(0xff0a0220),
    panel = Color(0xff18083c),
    panel2 = Color(0xff250e52),
    pink = Color(0xffff0d9e),
    muted = Color(0xffa59ab8);
final linkStyle = TextButton.styleFrom(
  backgroundColor: Colors.transparent,
  foregroundColor: const Color(0xffff9bd8),
  padding: const EdgeInsets.symmetric(horizontal: 3),
  minimumSize: const Size(0, 40),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);
late AppStore store;
final routeObserver = RouteObserver<PageRoute<dynamic>>();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  store = AppStore();
  await store.init();
  runApp(const TotiApp());
}

class TotiApp extends StatelessWidget {
  const TotiApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, _) => MaterialApp(
      key: ValueKey(store.get('language', 'en')),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      title: 'Toti',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        fontFamily: 'Quicksand',
        colorScheme: const ColorScheme.dark(primary: pink, surface: panel),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Quicksand'),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xfff7edff),
            backgroundColor: panel2,
            disabledForegroundColor: muted,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: const Size(48, 44),
            textStyle: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: panel,
          selectedColor: const Color(0xff593286),
          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
          side: BorderSide.none,
          showCheckmark: false,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          hintStyle: const TextStyle(color: muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        useMaterial3: true,
      ),
      home: AnimatedBuilder(
        animation: store,
        builder: (context, _) =>
            store.get('signedIn', false) ? const Shell() : const Login(),
      ),
    ),
  );
}

String tr(String source) {
  final lang = store.get('language', 'en') as String;
  return ((store.translations[lang] as Map<String, dynamic>?)?[source]
          as String?) ??
      source;
}

class TText extends Text {
  const TText(
    super.data, {
    super.key,
    super.style,
    super.textAlign,
    super.maxLines,
    super.overflow,
    super.softWrap,
    super.textDirection,
    super.semanticsLabel,
  });
  @override
  Widget build(BuildContext context) => Text(
    tr(data ?? ''),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    textDirection: textDirection,
    semanticsLabel: semanticsLabel,
  );
}

void open(BuildContext c, Widget page) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => page));
void notice(BuildContext c, String title, String message) => showDialog<void>(
  context: c,
  builder: (c) => AlertDialog(
    title: TText(title),
    content: TText(message),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const TText('OK')),
    ],
  ),
);
Widget photo(String name, {BoxFit fit = BoxFit.cover}) => Image.asset(
  'assets/portraits/$name',
  fit: fit,
  errorBuilder: (_, _, _) => Container(color: panel2),
);
Widget avatar(String name, {double size = 48}) => ClipOval(
  child: SizedBox(width: size, height: size, child: photo(name)),
);
// Each fifth of the original artwork is one navigation pictogram.
Widget navigationArtwork(int index, {bool selected = false}) => Opacity(
  opacity: selected ? 1 : .62,
  child: SizedBox(
    width: 26,
    height: 26,
    child: ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: -index * 26.0,
            top: -(130 / 3 - 26) / 2,
            child: Image.asset('assets/art/toti-navigation-icons.png', width: 130),
          ),
        ],
      ),
    ),
  ),
);
Widget action(String label, VoidCallback onTap, {bool primary = false}) =>
    SizedBox(
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: primary ? pink : panel2,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: TText(label, textAlign: TextAlign.center),
      ),
    );
Widget header(String s) => TText(
  s,
  style: const TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontWeight: FontWeight.bold,
    fontSize: 25,
  ),
);
Widget card(
  Widget child, {
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
}) => Material(
  color: panel,
  borderRadius: BorderRadius.circular(16),
  clipBehavior: Clip.antiAlias,
  child: Padding(padding: padding, child: child),
);

class Screen extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const Screen(this.title, this.child, {this.actions, super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
        child: TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => Navigator.maybePop(c),
          child: const TText('Back'),
        ),
      ),
      leadingWidth: 76,
      title: TText(title),
      actions: actions,
    ),
    body: SafeArea(child: child),
  );
}

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool accepted = false;
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/art/account-entry-scene.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: .48)),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                const Spacer(),
                header('Toti'),
                const SizedBox(height: 8),
                const TText(
                  'Find your people. Share your moments.',
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                action('Quick login', () {
                  if (!accepted) {
                    notice(
                      c,
                      'Agree to continue',
                      'Please review and accept the Terms of Service and Privacy Policy.',
                    );
                    return;
                  }
                  store.login();
                }, primary: true),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: accepted,
                      onChanged: (v) => setState(() => accepted = v ?? false),
                    ),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const TText('I am 18 or older and agree to the '),
                          TextButton(
                            style: linkStyle,
                            onPressed: () => open(
                              c,
                              const PolicyPage('Terms of Service', 'terms.txt'),
                            ),
                            child: const TText('Terms of Service'),
                          ),
                          const TText(' and '),
                          TextButton(
                            style: linkStyle,
                            onPressed: () => open(
                              c,
                              const PolicyPage('Privacy Policy', 'privacy.txt'),
                            ),
                            child: const TText('Privacy Policy'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class PolicyPage extends StatelessWidget {
  final String title, file;
  const PolicyPage(this.title, this.file, {super.key});
  @override
  Widget build(BuildContext c) => Screen(
    title,
    FutureBuilder<String>(
      future: DefaultAssetBundle.of(c).loadString('assets/legal/$file'),
      builder: (c, result) {
        if (result.hasError) {
          return const Center(child: TText('Unable to open this policy.'));
        }
        if (!result.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sections = result.data!.trim().split('\n\n');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final section in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TText(
                  section,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 1;
  @override
  void initState() {
    super.initState();
    if (store.get('welcomeShown', false) != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        store.put('welcomeShown', true);
        showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const TText('Welcome to Toti'),
            content: const TText('Your first login gift: 888 coins.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const TText('Continue'),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: store,
    builder: (c, _) {
      final pages = [
        Reels(active: tab == 0),
        const Discover(),
        const Rooms(),
        const Inbox(),
        const Profile(),
      ];
      final labels = ['Video', 'Discover', 'Party', 'Message', 'Profile'];
      return Scaffold(
        body: SafeArea(bottom: false, child: pages[tab]),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xff10072b),
              border: Border(top: BorderSide(color: Color(0xff33234e))),
            ),
            height: 76,
            child: Row(
              children: List.generate(
                5,
                (i) => Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == tab,
                    label: tr(labels[i]),
                    child: InkWell(
                      onTap: () => setState(() => tab = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 32,
                              decoration: BoxDecoration(
                                color: i == tab ? const Color(0xff4a1c62) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: navigationArtwork(i, selected: i == tab),
                            ),
                            const SizedBox(height: 3),
                            ExcludeSemantics(
                              child: TText(
                                labels[i],
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: i == tab ? const Color(0xffffb0de) : muted,
                                  fontWeight: i == tab ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class Discover extends StatefulWidget {
  const Discover({super.key});
  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  String category = 'All', region = 'Global', query = '';
  Future<void> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          notice(
            context,
            'Location unavailable',
            'Enable location services and try again.',
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          notice(
            context,
            'Location unavailable',
            'Allow location access in Android settings to use this feature.',
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final places = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final code = places.isEmpty
          ? ''
          : (places.first.isoCountryCode ?? '').toUpperCase();
      const europe = [
        'GB',
        'IE',
        'FR',
        'DE',
        'ES',
        'PT',
        'IT',
        'NL',
        'BE',
        'NO',
        'SE',
        'DK',
        'FI',
        'CH',
        'AT',
        'PL',
        'CZ',
        'GR',
        'TR',
      ];
      const asia = [
        'CN',
        'JP',
        'KR',
        'SG',
        'MY',
        'PH',
        'TH',
        'VN',
        'ID',
        'TW',
        'HK',
      ];
      const latin = ['MX', 'BR', 'AR', 'CL', 'CO', 'PE', 'UY', 'EC'];
      const mena = ['MA', 'AE', 'SA', 'EG', 'QA', 'JO', 'LB', 'TN', 'DZ'];
      const africa = [
        'ZA',
        'NG',
        'GH',
        'KE',
        'TZ',
        'UG',
        'ET',
        'RW',
        'SN',
        'CI',
        'CM',
        'BW',
        'NA',
        'ZM',
        'ZW',
      ];
      final result = code == 'IN'
          ? 'India'
          : europe.contains(code)
          ? 'Europe'
          : asia.contains(code)
          ? 'Asia'
          : latin.contains(code)
          ? 'Latin'
          : mena.contains(code)
          ? 'MENA'
          : africa.contains(code)
          ? 'Africa'
          : ['US', 'CA'].contains(code)
          ? 'North America'
          : ['AU', 'NZ'].contains(code)
          ? 'Oceania'
          : 'Global';
      if (mounted) setState(() => region = result);
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Location unavailable',
          'Could not determine your region. Please select one manually.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final members = store.members
        .where(
          (m) =>
              !store.list('blocked').contains(m.id) &&
              (category == 'All' ||
                  category == 'New' ||
                  (category == 'Live' && m.live) ||
                  (category == 'Follow' &&
                      store.list('following').contains(m.id))) &&
              (region == 'Global' || m.region == region) &&
              m.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Row(
            children: [
              Expanded(child: header('Discover')),
              TextButton(
                onPressed: () => createMenu(c),
                child: const TText('Create'),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TextButton(
                onPressed: locate,
                child: const TText('Use my region'),
              ),
              TextButton(
                onPressed: () => open(c, const Boutique()),
                child: const TText('Boutique'),
              ),
              const TText('Example profiles', style: TextStyle(color: muted)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Search people',
              filled: true,
              fillColor: panel,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in ['All', 'Live', 'Follow', 'New'])
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: TText(t),
                    selected: category == t,
                    onSelected: (_) => setState(() => category = t),
                  ),
                ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: region,
                items:
                    [
                          'Global',
                          'North America',
                          'Europe',
                          'Asia',
                          'India',
                          'Latin',
                          'MENA',
                          'Africa',
                          'Oceania',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: TText(e)))
                        .toList(),
                onChanged: (v) => setState(() => region = v ?? 'Global'),
              ),
            ],
          ),
        ),
        Expanded(
          child: members.isEmpty
              ? const Center(child: TText('No profiles found'))
              : LayoutBuilder(
                  builder: (c, box) => GridView.builder(
                    padding: const EdgeInsets.all(6),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: box.maxWidth > 700 ? 4 : 2,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: .73,
                    ),
                    itemCount: members.length,
                    itemBuilder: (c, i) {
                      final m = members[i];
                      return GestureDetector(
                        onTap: () => m.live
                            ? open(c, LiveRoom(m))
                            : open(c, MemberPage(m)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              photo(m.image),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.center,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black87,
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 10,
                                right: 10,
                                bottom: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m.live)
                                      const TText(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.pinkAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    TText(
                                      '${m.name}, ${m.age}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    TText(
                                      '${m.country}  ${m.region}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class MemberPage extends StatelessWidget {
  final Member member;
  const MemberPage(this.member, {super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: store,
    builder: (c, _) {
      final following = store.list('following').contains(member.id);
      return Screen(
        member.name,
        ListView(
          children: [
            SizedBox(
              height: 440,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo(member.image),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    bottom: 18,
                    child: TText(
                      '${member.name}, ${member.age}\n${member.country}  ${member.region}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header('About'),
                  const SizedBox(height: 8),
                  TText(member.bio),
                  const SizedBox(height: 20),
                  header('Interests'),
                  Wrap(
                    spacing: 8,
                    children: member.interests
                        .map((e) => Chip(label: TText(e)))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TText(member.doorway, style: const TextStyle(color: muted)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: action(
                          following ? 'Following' : 'Follow',
                          () => store.toggle('following', member.id),
                          primary: !following,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: action('Message', () {
                          if (!store.mutual(member)) {
                            notice(
                              c,
                              'Mutual follow required',
                              'You and ${member.name} must both follow each other before messaging.',
                            );
                            return;
                          }
                          open(c, Conversation(member));
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  action(
                    'Report or block',
                    () => safety(c, 'profile:${member.id}', member),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

void safety(BuildContext c, String id, Member? member) {
  showModalBottomSheet(
    context: c,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const TText('Report content'),
            onTap: () {
              Navigator.pop(ctx);
              report(c, id, member);
            },
          ),
          if (member != null)
            ListTile(
              title: TText('Block ${member.name}'),
              onTap: () {
                Navigator.pop(ctx);
                showDialog<void>(
                  context: c,
                  builder: (d) => AlertDialog(
                    title: TText('Block ${member.name}?'),
                    content: const TText(
                      'Their profile and activity will be hidden on this device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d),
                        child: const TText('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          store.block(member);
                          Navigator.pop(d);
                          Navigator.popUntil(c, (r) => r.isFirst);
                        },
                        child: const TText('Block'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

void report(BuildContext c, String id, Member? member) {
  showModalBottomSheet(
    context: c,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: TText('Why are you reporting this?')),
          for (final reason in [
            'Harassment',
            'Sexual content',
            'Violence or threats',
            'Spam or scam',
            'Other',
          ])
            ListTile(
              title: TText(reason),
              onTap: () {
                store.addRecord('reports', {
                  'id': id,
                  'user': member?.id,
                  'reason': reason,
                });
                Navigator.pop(ctx);
                notice(
                  c,
                  'Report recorded',
                  'The report is stored on this device. Reported videos and moments are hidden here.',
                );
              },
            ),
        ],
      ),
    ),
  );
}

class Reels extends StatefulWidget {
  final bool active;
  const Reels({required this.active, super.key});
  @override
  State<Reels> createState() => _ReelsState();
}

class _ReelsState extends State<Reels> with WidgetsBindingObserver, RouteAware {
  bool routeVisible = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    routeVisible = false;
    player?.pause();
  }

  @override
  void didPopNext() {
    routeVisible = true;
    if (widget.active && !paused) player?.play();
  }

  VideoPlayerController? player;
  int index = 0;
  int loadGeneration = 0;
  bool paused = false;
  String? loadedVideo;
  void storeChanged() {
    if (!mounted) return;
    if (reels.isEmpty) {
      if (loadedVideo != null) {
        loadedVideo = null;
        load();
      }
      return;
    }
    if (index >= reels.length) index = reels.length - 1;
    if (loadedVideo != reels[index]['video']) {
      load();
    }
  }

  List<dynamic> get reels => (store.data['reels'] as List).where((r) {
    final i = (store.data['reels'] as List).indexOf(r);
    return !store.list('blocked').contains('member-$i') &&
        !store.records('reports').any((x) => x['id'] == 'reel:${r['video']}');
  }).toList();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(storeChanged);
    load();
  }

  @override
  void didUpdateWidget(covariant Reels old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      if (widget.active && !paused) {
        player?.play();
      } else {
        player?.pause();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) {
      player?.pause();
    } else if (widget.active && !paused && routeVisible) {
      player?.play();
    }
  }

  Future<void> load() async {
    final generation = ++loadGeneration;
    final old = player;
    player = null;
    await old?.dispose();
    if (!mounted ||
        generation != loadGeneration ||
        reels.isEmpty ||
        index >= reels.length) {
      return;
    }
    loadedVideo = reels[index]['video'];
    final p = VideoPlayerController.asset('assets/videos/$loadedVideo');
    player = p;
    try {
      await p.initialize();
      if (!mounted || player != p) return;
      await p.setLooping(true);
      if (widget.active && routeVisible) await p.play();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(storeChanged);
    routeObserver.unsubscribe(this);
    loadGeneration++;
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (reels.isEmpty) return const Center(child: TText('No videos available'));
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: reels.length,
      onPageChanged: (v) {
        setState(() => index = v);
        paused = false;
        load();
      },
      itemBuilder: (c, i) {
        final r = reels[i];
        final original = (store.data['reels'] as List).indexOf(r);
        final m = store.members[original];
        final id = 'reel:${r['video']}';
        final liked = store.list('likes').contains(id);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (i == index && player?.value.isInitialized == true)
              GestureDetector(
                onTap: () {
                  setState(() => paused = !paused);
                  paused ? player?.pause() : player?.play();
                },
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: player!.value.size.width,
                    height: player!.value.size.height,
                    child: VideoPlayer(player!),
                  ),
                ),
              )
            else
              photo(m.image),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: TextButton(
                onPressed: () => safety(c, id, m),
                child: const TText('Report'),
              ),
            ),
            Positioned(
              left: 18,
              right: 90,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () => open(c, MemberPage(m)),
                    child: TText(
                      '@${m.name.toLowerCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TText(r['caption']),
                ],
              ),
            ),
            Positioned(
              right: 8,
              bottom: 20,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => open(c, MemberPage(m)),
                    child: avatar(m.image),
                  ),
                  TextButton(
                    onPressed: () => store.toggle('likes', id),
                    child: TText(liked ? 'Liked' : 'Like'),
                  ),
                  TextButton(
                    onPressed: () => open(c, Comments(id)),
                    child: const TText('Comments'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class Comments extends StatefulWidget {
  final String id;
  const Comments(this.id, {super.key});
  @override
  State<Comments> createState() => _CommentsState();
}

class _CommentsState extends State<Comments> {
  final field = TextEditingController();
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    store.addListener(refresh);
  }

  @override
  void dispose() {
    store.removeListener(refresh);
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final comments = store
        .records('comments')
        .where(
          (x) =>
              x['content'] == widget.id &&
              !store.list('blocked').contains(x['member']) &&
              !store
                  .records('reports')
                  .any((r) => r['id'] == 'comment:${x['id'] ?? x['text']}'),
        )
        .toList()
        .reversed
        .toList();
    return Screen(
      'Comments',
      Column(
        children: [
          Expanded(
            child: comments.isEmpty
                ? const Center(child: TText('No comments yet'))
                : ListView(
                    children: [
                      for (final e in comments)
                        ListTile(
                          title: TText(e['author']),
                          subtitle: TText(e['text']),
                          trailing: TextButton(
                            onPressed: () {
                              final member = store.members
                                  .where((m) => m.id == e['member'])
                                  .firstOrNull;
                              safety(
                                c,
                                'comment:${e['id'] ?? e['text']}',
                                member,
                              );
                            },
                            child: const TText('Report'),
                          ),
                        ),
                    ],
                  ),
          ),
          composer(field, () {
            final t = field.text.trim();
            if (!allowed(t)) {
              notice(
                c,
                'Comment not sent',
                'Please enter a clear, safe message.',
              );
              return;
            }
            store.addRecord('comments', {
              'content': widget.id,
              'id': DateTime.now().microsecondsSinceEpoch.toString(),
              'author': store.get('nickname', 'Nani Kohli'),
              'text': t,
            });
            field.clear();
            setState(() {});
          }),
        ],
      ),
    );
  }
}

Widget composer(TextEditingController field, VoidCallback send) => Padding(
  padding: const EdgeInsets.all(12),
  child: Row(
    children: [
      Expanded(
        child: TextField(
          controller: field,
          decoration: const InputDecoration(
            hintText: 'Write a message',
            filled: true,
            fillColor: panel,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
      ),
      TextButton(onPressed: send, child: const TText('Send')),
    ],
  ),
);

const roomSeeds = <Map<String, dynamic>>[
  {
    'id': 'glow-after-dark',
    'title': 'Glow After Dark',
    'summary': 'Music · stories · easy company',
    'host': '0',
    'cover': 'riverside-wheel-view.jpg',
    'tag': 'Featured',
    'audience': 'English',
    'guests': [0, 3, 5],
  },
  {
    'id': 'city-pop-lounge',
    'title': 'City Pop Lounge',
    'summary': 'Live playlist',
    'host': '6',
    'cover': 'yellow-cab-corner.jpg',
    'tag': 'Music',
    'audience': 'Spain',
    'guests': [6, 7, 9],
  },
  {
    'id': 'coffee-good-news',
    'title': 'Coffee & Good News',
    'summary': 'English room',
    'host': '10',
    'cover': 'waterfront-blue-sky.jpg',
    'tag': 'Conversation',
    'audience': 'English',
    'guests': [10, 11, 15],
  },
  {
    'id': 'game-night',
    'title': 'Game Night',
    'summary': 'Friendly challenges',
    'host': '17',
    'cover': 'metro-bandana.jpg',
    'tag': 'Games',
    'audience': 'India',
    'guests': [17, 18, 19],
  },
  {
    'id': 'travel-postcards',
    'title': 'Travel Postcards',
    'summary': 'Share your favorite view',
    'host': '21',
    'cover': 'sunhat-lakeside.jpg',
    'tag': 'Travel',
    'audience': 'Turkey',
    'guests': [21, 22, 23],
  },
  {
    'id': 'late-night-cinema',
    'title': 'Late Night Cinema',
    'summary': "Tonight's watch list",
    'host': '27',
    'cover': 'car-window-portrait.webp',
    'tag': 'Cinema',
    'audience': 'China',
    'guests': [27, 28, 29],
  },
];

class Rooms extends StatefulWidget {
  const Rooms({super.key});
  @override
  State<Rooms> createState() => _RoomsState();
}

class _RoomsState extends State<Rooms> {
  String query = '', tab = 'Party', audience = 'All';
  @override
  Widget build(BuildContext c) {
    var rooms = [...store.records('rooms'), ...roomSeeds].where((r) {
      final host = 'member-${r['host'] ?? '0'}';
      final text = '${r['title']} ${r['summary']}'.toLowerCase();
      return !store.list('blocked').contains(host) &&
          !store
              .records('reports')
              .any((x) => x['id'] == 'room:${r['id'] ?? r['title']}') &&
          (tab != 'Follow' || store.list('following').contains(host)) &&
          (audience == 'All' || (r['audience'] ?? 'English') == audience) &&
          text.contains(query.toLowerCase());
    }).toList();
    if (tab == 'Recent') rooms = rooms.reversed.toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in ['Party', 'Follow', 'Recent'])
                  TextButton(
                    onPressed: () => setState(() => tab = t),
                    child: TText(
                      t,
                      style: TextStyle(
                        color: tab == t ? Colors.white : muted,
                        fontWeight: tab == t
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => open(c, const Boutique()),
                  child: const TText('Store'),
                ),
                TextButton(
                  onPressed: () => open(c, const RoomEditor()),
                  child: const TText('Create'),
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final a in [
                'All',
                'English',
                'Spain',
                'India',
                'Turkey',
                'China',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: TText(a),
                    selected: audience == a,
                    onSelected: (_) => setState(() => audience = a),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: tr('Search rooms'),
              filled: true,
              fillColor: panel,
              border: const OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: rooms.isEmpty
              ? const Center(child: TText('No rooms found'))
              : LayoutBuilder(
                  builder: (c, box) {
                    final columns = box.maxWidth >= 700 ? 3 : 2;
                    final width =
                        (box.maxWidth - 28 - (columns - 1) * 10) / columns;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                      children: [
                        roomTile(c, rooms.first, box.maxWidth - 28, 172),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final r in rooms.skip(1))
                              roomTile(c, r, width, 198),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget roomTile(
    BuildContext c,
    Map<String, dynamic> room,
    double width,
    double height,
  ) {
    final cover = room['cover'] as String?;
    final guests =
        room['guests'] as List? ?? [int.tryParse('${room['host']}') ?? 0];
    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        onTap: () => open(c, RoomInvitation(room)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                photo(cover)
              else
                Image.asset(
                  'assets/art/presence-constellation-field.png',
                  fit: BoxFit.cover,
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pink,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: TText(
                    room['tag'] ?? 'Room',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TText(
                      room['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TText(
                      room['summary'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final n in guests.take(3))
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: avatar(
                              store.members[n as int].image,
                              size: 25,
                            ),
                          ),
                        const SizedBox(width: 4),
                        const Flexible(
                          child: TText(
                            'Example room',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoomInvitation extends StatelessWidget {
  final Map<String, dynamic> room;
  const RoomInvitation(this.room, {super.key});
  @override
  Widget build(BuildContext c) => Screen(
    room['title'],
    ListView(
      children: [
        SizedBox(
          height: 320,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (room['cover'] != null)
                photo(room['cover'])
              else
                Image.asset(
                  'assets/art/presence-constellation-field.png',
                  fit: BoxFit.cover,
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, bg],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header(room['title']), TText(room['summary'])],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TText(
                'A space to explore a shared interest. This room is an example; messages remain on your device.',
                style: TextStyle(fontSize: 15, color: muted),
              ),
              const SizedBox(height: 24),
              action(
                'Enter room',
                () => open(c, RoomPage(room)),
                primary: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class RoomEditor extends StatefulWidget {
  const RoomEditor({super.key});
  @override
  State<RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<RoomEditor> {
  final title = TextEditingController(), summary = TextEditingController();
  String topic = 'Conversation';
  @override
  void dispose() {
    title.dispose();
    summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Screen(
    'Create room',
    ListView(
      padding: const EdgeInsets.all(18),
      children: [
        header('Start a conversation'),
        const SizedBox(height: 20),
        TextField(
          controller: title,
          maxLength: 48,
          decoration: const InputDecoration(labelText: 'Room title'),
        ),
        TextField(
          controller: summary,
          maxLength: 160,
          decoration: const InputDecoration(
            labelText: 'What is your room about?',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final t in [
              'Conversation',
              'Music',
              'City notes',
              'Cinema',
              'Travel',
              'Creative',
            ])
              ChoiceChip(
                label: TText(t),
                selected: topic == t,
                onSelected: (_) => setState(() => topic = t),
              ),
          ],
        ),
        const SizedBox(height: 20),
        action('Create room', () {
          if (title.text.trim().length < 3 ||
              summary.text.trim().length < 8 ||
              !allowed(title.text) ||
              !allowed(summary.text)) {
            notice(
              c,
              'Check your room',
              'Use a 3–48 character room name and an 8–160 character note.',
            );
            return;
          }
          final room = {
            'title': title.text.trim(),
            'summary': summary.text.trim(),
            'host': '0',
            'tag': topic,
            'id': DateTime.now().microsecondsSinceEpoch.toString(),
          };
          store.addRecord('rooms', room);
          Navigator.pop(c);
          open(c, RoomPage(room));
        }, primary: true),
      ],
    ),
  );
}

class RoomPage extends StatefulWidget {
  final Map<String, dynamic> room;
  const RoomPage(this.room, {super.key});
  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage>
    with WidgetsBindingObserver, RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    stopMic();
  }

  final field = TextEditingController();
  final recorder = AudioRecorder();
  StreamSubscription<dynamic>? audioStream;
  bool onStage = false, micActive = false, micBusy = false;
  int micGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> stopMic() async {
    micGeneration++;
    await audioStream?.cancel();
    audioStream = null;
    try {
      await recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => micActive = false);
  }

  Future<void> toggleMic() async {
    if (micBusy) return;
    if (micActive) {
      await stopMic();
      return;
    }
    micBusy = true;
    final generation = ++micGeneration;
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          notice(
            context,
            'Microphone unavailable',
            'Allow microphone access to use the stage.',
          );
        }
        return;
      }
      if (!mounted || generation != micGeneration) return;
      final stream = await recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits),
      );
      if (!mounted || generation != micGeneration) {
        await recorder.stop();
        return;
      }
      audioStream = stream.listen(
        (_) {},
        onError: (_) {
          if (mounted) {
            notice(
              context,
              'Microphone unavailable',
              'The microphone stream stopped.',
            );
          }
          stopMic();
        },
      );
      setState(() {
        onStage = true;
        micActive = true;
      });
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Microphone unavailable',
          'Check device permissions and try again.',
        );
      }
    } finally {
      micBusy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) stopMic();
  }

  @override
  void dispose() {
    micGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    audioStream?.cancel();
    recorder.dispose();
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final id = 'room:${widget.room['id'] ?? widget.room['title']}';
    final host = store.members[int.tryParse('${widget.room['host']}') ?? 0];
    final messages = store
        .records('roomMessages')
        .where((e) => e['room'] == id)
        .toList()
        .reversed;
    return Screen(
      widget.room['title'],
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: card(
              Column(
                children: [
                  avatar(host.image, size: 80),
                  const SizedBox(height: 8),
                  TText(widget.room['summary']),
                  const SizedBox(height: 8),
                  const TText(
                    'Example room · no audio is sent to others',
                    style: TextStyle(color: muted),
                  ),
                  TextButton(
                    onPressed: () => open(c, MemberPage(host)),
                    child: TText('Host: ${host.name}'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? const Center(child: TText('Say hello to the room'))
                : ListView(
                    children: [
                      for (final e in messages)
                        ListTile(
                          title: TText(e['author']),
                          subtitle: TText(e['text']),
                        ),
                    ],
                  ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: toggleMic,
                  child: TText(
                    micActive
                        ? 'Mute'
                        : onStage
                        ? 'Unmute'
                        : 'Join stage',
                  ),
                ),
                TextButton(
                  onPressed: () => showRoomMembers(c, widget.room),
                  child: const TText('Members'),
                ),
                TextButton(
                  onPressed: () async {
                    await showGifts(c, id);
                    if (mounted) setState(() {});
                  },
                  child: const TText('Gifts'),
                ),

                TextButton(
                  onPressed: () => safety(c, id, host),
                  child: const TText('Report'),
                ),
              ],
            ),
          ),
          composer(field, () {
            if (!allowed(field.text)) {
              notice(
                c,
                'Message not sent',
                'Please enter a clear, safe message.',
              );
              return;
            }
            store.addRecord('roomMessages', {
              'room': id,
              'author': store.get('nickname', 'Nani Kohli'),
              'text': field.text.trim(),
            });
            field.clear();
            setState(() {});
          }),
        ],
      ),
    );
  }
}

void showRoomMembers(BuildContext context, Map<String, dynamic> room) {
  final guests =
      room['guests'] as List? ?? [int.tryParse('${room['host']}') ?? 0];
  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: TText('Room members')),
          for (final n in guests)
            if (!store.list('blocked').contains(store.members[n as int].id))
              ListTile(
                leading: avatar(store.members[n].image),
                title: TText(store.members[n].name),
                onTap: () {
                  Navigator.pop(sheet);
                  open(context, MemberPage(store.members[n]));
                },
              ),
        ],
      ),
    ),
  );
}

Future<void> showGifts(BuildContext context, String roomId) async {
  const gifts = [
    ['Rose', 25],
    ['Kiss', 60],
    ['Crown', 180],
    ['Rocket', 520],
  ];
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TText(
              'Choose a gift',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const TText(
              'This example gift is recorded on your device; it is not delivered to another person.',
              style: TextStyle(color: muted),
            ),
            for (final gift in gifts)
              ListTile(
                title: TText(gift[0] as String),
                subtitle: TText('${gift[1]} coins'),
                onTap: () {
                  final balance = store.get('coins', 0) as int;
                  final cost = gift[1] as int;
                  if (balance < cost) {
                    Navigator.pop(sheet);
                    notice(
                      context,
                      'More coins needed',
                      'Your current balance is $balance coins.',
                    );
                    return;
                  }
                  store.state['coins'] = balance - cost;
                  final records = store.records('roomMessages');
                  records.insert(0, {
                    'room': roomId,
                    'author': store.get('nickname', 'Nani Kohli'),
                    'text': 'Selected ${gift[0]} as a local gift',
                  });
                  store.state['roomMessages'] = records;
                  store.save();
                  Navigator.pop(sheet);
                  notice(
                    context,
                    'Gift recorded',
                    '${gift[0]} was recorded on this device.',
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class LiveRoom extends StatefulWidget {
  final Member member;
  const LiveRoom(this.member, {super.key});
  @override
  State<LiveRoom> createState() => _LiveRoomState();
}

class _LiveRoomState extends State<LiveRoom>
    with WidgetsBindingObserver, RouteAware {
  bool routeVisible = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    routeVisible = false;
    p?.pause();
  }

  @override
  void didPopNext() {
    routeVisible = true;
    p?.play();
  }

  VideoPlayerController? p;
  final field = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    p = VideoPlayerController.asset(
      'assets/videos/${store.data['liveVideos'][store.members.where((m) => m.live).toList().indexWhere((m) => m.id == widget.member.id) % 9]}',
    );
    p!
        .initialize()
        .then((_) {
          if (!mounted) return;
          p!.setLooping(true);
          if (routeVisible) p!.play();
          setState(() {});
        })
        .catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) {
      p?.pause();
    } else if (routeVisible) {
      p?.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    p?.dispose();
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final id = 'live:${widget.member.id}';
    return Screen(
      'Live',
      Stack(
        fit: StackFit.expand,
        children: [
          if (p?.value.isInitialized == true)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: p!.value.size.width,
                height: p!.value.size.height,
                child: VideoPlayer(p!),
              ),
            )
          else
            photo(widget.member.image),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Row(
              children: [
                avatar(widget.member.image),
                const SizedBox(width: 8),
                Expanded(
                  child: TText(
                    widget.member.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => open(c, MemberPage(widget.member)),
                  child: const TText('Profile'),
                ),
                TextButton(
                  onPressed: () => safety(c, id, widget.member),
                  child: const TText('Report'),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TText(
                  'Editorial video · local playback',
                  style: TextStyle(color: Colors.white70),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        store.toggle('following', widget.member.id);
                        setState(() {});
                      },
                      child: TText(
                        store.list('following').contains(widget.member.id)
                            ? 'Following'
                            : 'Follow',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final key = 'liveHeart:${widget.member.id}';
                        store.put(key, (store.get(key, 0) as int) + 1);
                        setState(() {});
                      },
                      child: TText(
                        'Like · ${store.get('liveHeart:${widget.member.id}', 0)}',
                      ),
                    ),
                  ],
                ),
                for (final msg
                    in store
                        .records('roomMessages')
                        .where((m) => m['room'] == id)
                        .take(3)
                        .toList()
                        .reversed)
                  TText('${msg['author']}: ${msg['text']}'),
                Row(
                  children: [
                    Expanded(
                      child: composer(field, () {
                        if (!allowed(field.text)) {
                          notice(
                            c,
                            'Message not sent',
                            'Please enter a clear, safe message.',
                          );
                          return;
                        }
                        store.addRecord('roomMessages', {
                          'room': id,
                          'author': store.get('nickname', 'Nani Kohli'),
                          'text': field.text.trim(),
                        });
                        field.clear();
                        setState(() {});
                      }),
                    ),
                    TextButton(
                      onPressed: () async {
                        await showGifts(c, id);
                        if (mounted) setState(() {});
                      },
                      child: const TText('Gift'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Inbox extends StatefulWidget {
  const Inbox({super.key});
  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  String tab = 'Message';
  @override
  Widget build(BuildContext c) {
    final notices = store
        .records('notices')
        .where((n) => !store.list('blocked').contains(n['member']))
        .toList();
    final following = store.members
        .where(
          (m) =>
              store.list('following').contains(m.id) &&
              !store.list('blocked').contains(m.id),
        )
        .toList();
    final conversations = store.members
        .where(
          (m) =>
              store.mutual(m) &&
              store.records('messages').any((x) => x['member'] == m.id),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        header('Messages'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: action(
                'Platform updates',
                () => open(c, const PlatformUpdates()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: action(
                'Followers',
                () => open(c, const Relationships('Followers')),
              ),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in ['Message', 'Follow', 'Calls', 'Moments'])
                TextButton(
                  onPressed: () => setState(() => tab = t),
                  child: TText(
                    t,
                    style: TextStyle(
                      color: t == tab ? pink : muted,
                      fontWeight: t == tab
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (tab == 'Message') ...[
          for (final n in notices)
            if (n['member'] != null)
              ListTile(
                leading: avatar(
                  store.members.firstWhere((m) => m.id == n['member']).image,
                ),
                title: TText(n['text']),
                subtitle: const TText('Example profile activity'),
                trailing: n['read'] == true ? null : const TText('NEW'),
                onTap: () {
                  n['read'] = true;
                  final all = store.records('notices');
                  for (final item in all) {
                    if (item['member'] == n['member'] &&
                        item['text'] == n['text']) {
                      item['read'] = true;
                    }
                  }
                  store.put('notices', all);
                  setState(() {});
                  open(
                    c,
                    MemberPage(
                      store.members.firstWhere((m) => m.id == n['member']),
                    ),
                  );
                },
              ),
          for (final m in conversations)
            ListTile(
              leading: avatar(m.image),
              title: TText(m.name),
              subtitle: TText(
                store
                    .records('messages')
                    .firstWhere((x) => x['member'] == m.id)['text'],
              ),
              onTap: () => open(c, Conversation(m)),
            ),
          if (notices.isEmpty && conversations.isEmpty)
            const ListTile(
              title: TText('No messages yet'),
              subtitle: TText('Mutual follows can start a conversation'),
            ),
        ] else if (tab == 'Follow') ...[
          if (following.isEmpty)
            const ListTile(
              title: TText('No followed people yet'),
              subtitle: TText('Follow someone from Discover to see them here'),
            ),
          for (final m in following)
            ListTile(
              leading: avatar(m.image),
              title: TText(m.name),
              subtitle: TText('Following · ${m.country}'),
              onTap: () => store.mutual(m)
                  ? open(c, Conversation(m))
                  : open(c, MemberPage(m)),
            ),
        ] else if (tab == 'Calls')
          const ListTile(
            title: TText('No recent calls'),
            subtitle: TText('Calls are not connected'),
          )
        else
          ListTile(
            title: const TText('Moments'),
            subtitle: const TText('Browse the community feed'),
            onTap: () => open(c, const Moments()),
          ),
      ],
    );
  }
}

class PlatformUpdates extends StatefulWidget {
  const PlatformUpdates({super.key});
  @override
  State<PlatformUpdates> createState() => _PlatformUpdatesState();
}

class _PlatformUpdatesState extends State<PlatformUpdates> {
  @override
  Widget build(BuildContext c) {
    final notices = store
        .records('notices')
        .where((n) => !store.list('blocked').contains(n['member']))
        .toList();
    return Screen(
      'Platform updates',
      ListView(
        children: [
          if (notices.isNotEmpty)
            TextButton(
              onPressed: () {
                final all = store.records('notices');
                for (final n in all) {
                  n['read'] = true;
                }
                store.put('notices', all);
                setState(() {});
              },
              child: const TText('Mark all read'),
            ),
          if (notices.isEmpty)
            const ListTile(
              title: TText("You're all caught up"),
              subtitle: TText(
                'Account, safety and community updates will appear here.',
              ),
            ),
          for (final n in notices)
            ListTile(
              title: TText(n['text']),
              subtitle: TText(
                store.members
                        .where((m) => m.id == n['member'])
                        .map((m) => m.name)
                        .firstOrNull ??
                    '',
              ),
              trailing: n['read'] == true ? null : const TText('NEW'),
            ),
        ],
      ),
    );
  }
}

class Conversation extends StatefulWidget {
  final Member member;
  const Conversation(this.member, {super.key});
  @override
  State<Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<Conversation> {
  final field = TextEditingController();
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final m = widget.member;
    final messages = store
        .records('messages')
        .where((e) => e['member'] == m.id)
        .toList()
        .reversed;
    return Screen(
      m.name,
      Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(10),
            child: TText(
              'Messages are saved on this device only.',
              style: TextStyle(color: muted),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final msg in messages)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TText(msg['text']),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  if (store.mutual(m)) {
                    open(c, CallPreview(m, video: false));
                  } else {
                    notice(
                      c,
                      'Mutual follow required',
                      'Both people must follow each other.',
                    );
                  }
                },
                child: const TText('Voice call'),
              ),
              TextButton(
                onPressed: () {
                  if (store.mutual(m)) {
                    open(c, CallPreview(m, video: true));
                  } else {
                    notice(
                      c,
                      'Mutual follow required',
                      'Both people must follow each other.',
                    );
                  }
                },
                child: const TText('Video call'),
              ),
              TextButton(
                onPressed: () => safety(c, 'chat:${m.id}', m),
                child: const TText('Report'),
              ),
            ],
          ),
          composer(field, () {
            if (!store.mutual(m)) {
              notice(
                c,
                'Mutual follow required',
                'Both people must follow each other.',
              );
              return;
            }
            if (!allowed(field.text)) {
              notice(
                c,
                'Message not sent',
                'Please enter a clear, safe message.',
              );
              return;
            }
            store.addRecord('messages', {
              'member': m.id,
              'text': field.text.trim(),
            });
            field.clear();
            setState(() {});
          }),
        ],
      ),
    );
  }
}

class CallPreview extends StatefulWidget {
  final Member member;
  final bool video;
  const CallPreview(this.member, {required this.video, super.key});
  @override
  State<CallPreview> createState() => _CallPreviewState();
}

class _CallPreviewState extends State<CallPreview> with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  StreamSubscription<dynamic>? samples;
  CameraController? camera;
  Timer? timer;
  int elapsed = 0, generation = 0;
  bool mic = false, busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => elapsed++);
    });
  }

  Future<void> stopInputs() async {
    generation++;
    await samples?.cancel();
    samples = null;
    try {
      await recorder.stop();
    } catch (_) {}
    final previous = camera;
    camera = null;
    await previous?.dispose();
    if (mounted) setState(() => mic = false);
  }

  Future<void> toggleMic() async {
    if (busy) return;
    busy = true;
    if (mic) {
      try {
        await samples?.cancel();
        samples = null;
        await recorder.stop();
        if (mounted) setState(() => mic = false);
      } catch (_) {}
      busy = false;
      return;
    }
    final token = generation;
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          notice(
            context,
            'Microphone unavailable',
            'Allow microphone access in Android settings.',
          );
        }
        return;
      }
      final stream = await recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits),
      );
      if (!mounted || token != generation) {
        await recorder.stop();
        return;
      }
      samples = stream.listen((_) {});
      setState(() => mic = true);
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Microphone unavailable',
          'Please check your microphone permissions.',
        );
      }
    } finally {
      busy = false;
    }
  }

  Future<void> toggleCamera() async {
    if (busy) return;
    busy = true;
    final token = generation;
    try {
      if (camera != null) {
        final old = camera;
        camera = null;
        await old?.dispose();
        if (mounted) setState(() {});
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          notice(context, 'Camera unavailable', 'No camera was found.');
        }
        return;
      }
      final selected =
          cameras
              .where((c) => c.lensDirection == CameraLensDirection.front)
              .firstOrNull ??
          cameras.first;
      final next = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      camera = next;
      await next.initialize();
      if (!mounted || token != generation) return;
      setState(() {});
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Camera unavailable',
          'Please check your camera permissions.',
        );
      }
    } finally {
      busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) stopInputs();
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    samples?.cancel();
    recorder.dispose();
    camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Screen(
    widget.video ? 'Video call' : 'Voice call',
    Stack(
      fit: StackFit.expand,
      children: [
        photo(widget.member.image),
        Container(color: Colors.black.withValues(alpha: .65)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TText(
                  widget.member.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const TText(
                  'Local preview only · no call is connected',
                  textAlign: TextAlign.center,
                ),
                TText(
                  '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}',
                ),
                const Spacer(),
                if (camera?.value.isInitialized == true)
                  SizedBox(
                    height: 160,
                    child: AspectRatio(
                      aspectRatio: camera!.value.aspectRatio,
                      child: CameraPreview(camera!),
                    ),
                  ),
                const Spacer(),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    action(mic ? 'Mute' : 'Microphone', toggleMic),
                    if (widget.video)
                      action(
                        camera?.value.isInitialized == true
                            ? 'Camera off'
                            : 'Camera on',
                        toggleCamera,
                      ),
                    action('End', () => Navigator.pop(c), primary: true),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

void createMenu(BuildContext c) {
  showModalBottomSheet(
    context: c,
    builder: (d) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: TText('What do you want to share?')),
          ListTile(
            title: const TText('Go live'),
            subtitle: const TText('Camera and microphone'),
            onTap: () {
              Navigator.pop(d);
              open(c, const LiveSetup());
            },
          ),
          ListTile(
            title: const TText('Post a video'),
            onTap: () {
              Navigator.pop(d);
              open(c, const MomentEditor(video: true));
            },
          ),
          ListTile(
            title: const TText('Share a moment'),
            onTap: () {
              Navigator.pop(d);
              open(c, const MomentEditor());
            },
          ),
        ],
      ),
    ),
  );
}

class Moments extends StatelessWidget {
  const Moments({super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: store,
    builder: (c, _) {
      final moments = store.records('moments');
      final seed = [
        {
          'author': 'Mia Calder',
          'text': 'Slow mornings and a new favorite corner of the city.',
          'image': 'boulevard-snack-stop.jpg',
          'id': 'seed-0',
          'member': 'member-0',
        },
        {
          'author': 'Amara Ndlovu',
          'text': 'What song has been on repeat for you lately?',
          'image': 'evening-cat-cafe.jpg',
          'id': 'seed-1',
          'member': 'member-8',
        },
      ];
      final all = [...moments, ...seed]
          .where(
            (e) =>
                !store.list('blocked').contains(e['member']) &&
                !store
                    .records('reports')
                    .any((r) => r['id'] == 'moment:${e['id']}'),
          )
          .toList();
      return Screen(
        'Moments',
        ListView(
          padding: const EdgeInsets.all(14),
          children: [
            action(
              'Share a moment',
              () => open(c, const MomentEditor()),
              primary: true,
            ),
            const SizedBox(height: 12),
            for (final e in all)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TText(
                        e['author'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TText(e['text']),
                      if (e['image'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: e['path'] == true
                                ? Image.file(
                                    File(e['image']),
                                    height: 240,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : SizedBox(
                                    height: 240,
                                    width: double.infinity,
                                    child: photo(e['image']),
                                  ),
                          ),
                        ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                store.toggle('likes', 'moment:${e['id']}'),
                            child: TText(
                              store.list('likes').contains('moment:${e['id']}')
                                  ? 'Liked'
                                  : 'Like',
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                open(c, Comments('moment:${e['id']}')),
                            child: const TText('Comment'),
                          ),
                          TextButton(
                            onPressed: () => safety(
                              c,
                              'moment:${e['id']}',
                              store.members
                                  .where((m) => m.id == e['member'])
                                  .firstOrNull,
                            ),
                            child: const TText('Report'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class MomentEditor extends StatefulWidget {
  final bool video;
  const MomentEditor({this.video = false, super.key});
  @override
  State<MomentEditor> createState() => _MomentEditorState();
}

class _MomentEditorState extends State<MomentEditor> {
  final text = TextEditingController();
  XFile? media;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const TText("Choose from gallery"),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            ListTile(
              title: TText(widget.video ? "Record video" : "Take photo"),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final f = widget.video
          ? await ImagePicker().pickVideo(source: source)
          : await ImagePicker().pickImage(source: source);
      if (f != null && mounted) setState(() => media = f);
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Media unavailable',
          'Could not select media. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) => Screen(
    widget.video ? 'Post a video' : 'Share a moment',
    ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const TText(
          'Your submission is saved locally as pending. There is no connected review service.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: text,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            hintText: 'Share a thought',
            filled: true,
            fillColor: panel,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        TextButton(
          onPressed: choose,
          child: TText(
            media == null
                ? 'Choose ${widget.video ? 'video' : 'photo'}'
                : 'Media selected',
          ),
        ),
        const SizedBox(height: 16),
        action('Submit', () async {
          if (!allowed(text.text)) {
            notice(c, 'Please revise', 'Enter a clear, safe message.');
            return;
          }
          if (widget.video && media == null) {
            notice(c, 'Choose a video', 'Select a video to continue.');
            return;
          }
          String? path;
          try {
            if (media != null) {
              final dir = await getApplicationDocumentsDirectory();
              final extension = media!.name.contains('.')
                  ? '.${media!.name.split('.').last}'
                  : '';
              path =
                  '${dir.path}/moment_${DateTime.now().microsecondsSinceEpoch}$extension';
              await File(media!.path).copy(path);
            }
          } catch (_) {
            if (c.mounted) {
              notice(c, 'Could not save media', 'Please try again.');
            }
            return;
          }
          store.addRecord('pending', {
            'text': text.text.trim(),
            'path': path,
            'type': widget.video ? 'video' : 'photo',
          });
          if (c.mounted) {
            Navigator.pop(c);
            notice(
              c,
              'Saved as pending',
              'Your submission is stored on this device.',
            );
          }
        }, primary: true),
      ],
    ),
  );
}

class Profile extends StatelessWidget {
  const Profile({super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: store,
    builder: (c, _) {
      final following = store.list('following'),
          followers = store.list('followers');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => open(c, const Settings()),
              child: const TText('Settings'),
            ),
          ),
          Center(child: avatar('riverside-black-dress.jpg', size: 90)),
          const SizedBox(height: 12),
          Center(
            child: TText(
              store.get('nickname', 'Nani Kohli'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: TText(
              '${store.get('gender', 'Female')}  ·  ${store.get('country', 'SG')}',
              style: const TextStyle(color: muted),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => open(c, const EditProfile()),
              child: const TText('Edit profile'),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final entry in {
                'Friends': following.where(followers.contains).length,
                'Following': following.length,
                'Followers': followers.length,
              }.entries)
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => open(c, Relationships(entry.key)),
                    child: Column(
                      children: [
                        TText(
                          '${entry.value}',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TText(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => open(c, const Vault()),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff7029f2), pink],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TText('MY COIN VAULT'),
                  TText(
                    '${store.get('coins', 0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TText('View balance'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          card(
            Row(
              children: [
                const Expanded(
                  child: TText(
                    'Daily Coin Drop  +50',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (store.get('daily', '') == today) {
                      notice(
                        c,
                        'Already collected',
                        'Your next free Coin Drop arrives tomorrow.',
                      );
                      return;
                    }
                    store.state['daily'] = today;
                    store.state['coins'] = (store.get('coins', 0) as int) + 50;
                    store.save();
                    notice(
                      c,
                      '+50 coins',
                      "Today's Coin Drop landed in your balance.",
                    );
                  },
                  child: TText(
                    store.get('daily', '') == today ? 'Collected' : 'Collect',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          card(
            Column(
              children: [
                ListTile(
                  title: const TText('Moments'),
                  onTap: () => open(c, const Moments()),
                ),
                ListTile(
                  title: const TText('My submissions'),
                  onTap: () => open(c, const Pending()),
                ),
                ListTile(
                  title: const TText('Effect Boutique'),
                  onTap: () => open(c, const Boutique()),
                ),
                ListTile(
                  title: const TText('Backpack'),
                  onTap: () => open(c, const Backpack()),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class Relationships extends StatelessWidget {
  final String scope;
  const Relationships(this.scope, {super.key});
  @override
  Widget build(BuildContext c) {
    final following = store.list('following'),
        followers = store.list('followers');
    final ms = store.members
        .where(
          (m) =>
              !store.list('blocked').contains(m.id) &&
              (scope == 'Friends'
                  ? store.mutual(m)
                  : scope == 'Following'
                  ? following.contains(m.id)
                  : followers.contains(m.id)),
        )
        .toList();
    return Screen(
      scope,
      ms.isEmpty
          ? const Center(child: TText('No connections yet'))
          : ListView(
              children: [
                for (final m in ms)
                  ListTile(
                    leading: avatar(m.image),
                    title: TText(m.name),
                    subtitle: TText(m.region),
                    onTap: () => open(c, MemberPage(m)),
                  ),
              ],
            ),
    );
  }
}

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});
  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  late TextEditingController name, birthday, country;
  String gender = 'Female';
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: store.get('nickname', 'Nani Kohli'));
    birthday = TextEditingController(text: store.get('birthday', '2000-04-23'));
    country = TextEditingController(text: store.get('country', 'SG'));
    gender = store.get('gender', 'Female');
  }

  @override
  void dispose() {
    name.dispose();
    birthday.dispose();
    country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Screen(
    'Edit profile',
    ListView(
      padding: const EdgeInsets.all(18),
      children: [
        TextField(
          controller: name,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Nickname'),
        ),
        DropdownButtonFormField<String>(
          initialValue: gender,
          items: [
            'Female',
            'Male',
            'Other',
          ].map((e) => DropdownMenuItem(value: e, child: TText(e))).toList(),
          onChanged: (v) => gender = v ?? gender,
          decoration: const InputDecoration(labelText: 'Gender'),
        ),
        TextField(
          controller: birthday,
          decoration: const InputDecoration(labelText: 'Birthday (YYYY-MM-DD)'),
        ),
        TextField(
          controller: country,
          decoration: const InputDecoration(labelText: 'Country'),
        ),
        const SizedBox(height: 22),
        action('Save', () {
          final date = DateTime.tryParse(birthday.text);
          final now = DateTime.now();
          final adult =
              date != null &&
              !date.isAfter(DateTime(now.year - 18, now.month, now.day));
          if (!allowed(name.text) || !adult || country.text.trim().isEmpty) {
            notice(
              c,
              'Check your profile',
              'Enter a nickname, country and valid adult birthday.',
            );
            return;
          }
          store.state.addAll({
            'nickname': name.text.trim(),
            'gender': gender,
            'birthday': birthday.text,
            'country': country.text.trim(),
          });
          store.save();
          Navigator.pop(c);
        }, primary: true),
      ],
    ),
  );
}

const coinProducts = <String, int>{
  'toti_coins_500': 500,
  'toti_coins_1050': 1050,
  'toti_coins_1650': 1650,
  'toti_coins_2900': 2900,
  'toti_coins_6000': 6000,
  'toti_coins_12500': 12500,
  'toti_coins_33000': 33000,
  'toti_coins_72000': 72000,
  'toti_coins_115000': 115000,
};

class Vault extends StatefulWidget {
  const Vault({super.key});
  @override
  State<Vault> createState() => _VaultState();
}

class _VaultState extends State<Vault> {
  bool loading = true;
  String? error;
  List<ProductDetails> products = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!await InAppPurchase.instance.isAvailable()) {
        if (mounted) {
          setState(() {
            loading = false;
            error = 'Google Play is unavailable on this device.';
          });
        }
        return;
      }
      final response = await InAppPurchase.instance.queryProductDetails(
        coinProducts.keys.toSet(),
      );
      if (!mounted) return;
      setState(() {
        loading = false;
        products = response.productDetails
          ..sort((a, b) => coinProducts[a.id]!.compareTo(coinProducts[b.id]!));
        error =
            response.error?.message ??
            (products.isEmpty
                ? 'Coin packs are not available in this Play account.'
                : null);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Unable to load coin packs. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext c) => Screen(
    'Coin Vault',
    ListView(
      padding: const EdgeInsets.all(18),
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TText('YOUR BALANCE'),
              TText(
                '${store.get('coins', 0)} coins',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        header('Add coins'),
        const SizedBox(height: 8),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null) ...[
          TText(error!, style: const TextStyle(color: muted)),
          TextButton(onPressed: load, child: const TText('Try again')),
        ] else ...[
          for (final p in products)
            ListTile(
              title: TText('${coinProducts[p.id]} coins'),
              subtitle: TText(p.price),
              trailing: TextButton(
                onPressed: () => notice(
                  c,
                  'Purchases unavailable',
                  'Purchase verification is not configured yet.',
                ),
                child: const TText('Unavailable'),
              ),
            ),
        ],
        const SizedBox(height: 18),
        const TText(
          'Coins can be used for gifts and effects. Messaging and following do not use coins.',
        ),
      ],
    ),
  );
}

const effects = [
  ['rose', 'Rose Signal', 25, 'Live Gift'],
  ['roadster', 'Roadster Entry', 680, 'Entrance FX'],
  ['comet', 'Comet Entry', 260, 'Entrance FX'],
  ['kiss', 'Sweet Kiss', 60, 'Live Gift'],
  ['crown', 'Royal Crown', 180, 'Live Gift'],
  ['rocket', 'Night Rocket', 520, 'Live Gift'],
  ['aurora', 'Aurora Aura', 340, 'Profile Aura'],
  ['heart', 'Heart Aura', 220, 'Profile Aura'],
  ['star', 'Starlight Aura', 460, 'Profile Aura'],
];

class Boutique extends StatefulWidget {
  const Boutique({super.key});
  @override
  State<Boutique> createState() => _BoutiqueState();
}

class _BoutiqueState extends State<Boutique> {
  String category = 'All';
  @override
  Widget build(BuildContext c) {
    final items = effects
        .where((e) => category == 'All' || e[3] == category)
        .toList();
    return Screen(
      'Store',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.asset(
                  'assets/art/effect-boutique-aurora.png',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                const Positioned(
                  left: 18,
                  bottom: 18,
                  child: TText(
                    'Make their moment glow',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TText('Balance: ${store.get('coins', 0)} coins'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in [
                  'All',
                  'Live Gift',
                  'Entrance FX',
                  'Profile Aura',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: TText(t),
                      selected: category == t,
                      onSelected: (_) => setState(() => category = t),
                    ),
                  ),
              ],
            ),
          ),
          for (final e in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: card(
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TText(
                            e[1] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TText(
                            '${e[3]} · ${e[2]} coins',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final coins = store.get('coins', 0) as int;
                        final price = e[2] as int;
                        if (coins < price) {
                          notice(
                            c,
                            'More coins needed',
                            'Your current balance is $coins coins.',
                          );
                          return;
                        }
                        store.state['coins'] = coins - price;
                        final bag = store.records('backpack');
                        bag.add({'id': e[0], 'name': e[1]});
                        store.state['backpack'] = bag;
                        store.save();
                        setState(() {});
                        notice(
                          c,
                          'Added to Backpack',
                          '${e[1]} was collected on this device.',
                        );
                      },
                      child: const TText('Collect'),
                    ),
                  ],
                ),
              ),
            ),
          TextButton(
            onPressed: () => open(c, const Vault()),
            child: const TText('Get coins'),
          ),
        ],
      ),
    );
  }
}

class Backpack extends StatelessWidget {
  const Backpack({super.key});
  @override
  Widget build(BuildContext c) {
    final items = store.records('backpack');
    return Screen(
      'Backpack',
      items.isEmpty
          ? const Center(child: TText('Your backpack is empty'))
          : ListView(
              children: [
                for (final e in items)
                  ListTile(
                    title: TText(e['name']),
                    subtitle: const TText('Collected effect'),
                  ),
              ],
            ),
    );
  }
}

class Pending extends StatelessWidget {
  const Pending({super.key});
  @override
  Widget build(BuildContext c) {
    final items = store.records('pending');
    return Screen(
      'My submissions',
      items.isEmpty
          ? const Center(child: TText('No submissions yet'))
          : ListView(
              children: [
                for (final e in items)
                  ListTile(
                    title: TText(e['text']),
                    subtitle: const TText(
                      'Pending locally · no review service connected',
                    ),
                  ),
              ],
            ),
    );
  }
}

class Settings extends StatelessWidget {
  const Settings({super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: store,
    builder: (c, _) => Screen(
      'Settings',
      ListView(
        children: [
          ListTile(
            title: const TText('App language'),
            subtitle: TText(
              const {
                    'en': 'English',
                    'zh-Hans': '简体中文',
                    'es': 'Español',
                    'ja': '日本語',
                    'de': 'Deutsch',
                  }[store.get('language', 'en')] ??
                  'English',
            ),
            onTap: () => open(c, const LanguagePicker()),
          ),
          ListTile(
            title: const TText('Privacy Policy'),
            onTap: () =>
                open(c, const PolicyPage('Privacy Policy', 'privacy.txt')),
          ),
          ListTile(
            title: const TText('Terms of Service'),
            onTap: () =>
                open(c, const PolicyPage('Terms of Service', 'terms.txt')),
          ),
          ListTile(
            title: const TText('Community Guidelines'),
            onTap: () => open(c, const Guidelines()),
          ),
          ListTile(
            title: const TText('Blocked accounts'),
            onTap: () => open(c, const Blocked()),
          ),
          ListTile(
            title: const TText('About'),
            subtitle: const TText('Toti · Android'),
          ),
          SwitchListTile(
            title: const TText('Message do not disturb'),
            value: store.get('messageDND', false),
            onChanged: (v) => store.put('messageDND', v),
          ),
          SwitchListTile(
            title: const TText('Call do not disturb'),
            value: store.get('callDND', false),
            onChanged: (v) => store.put('callDND', v),
          ),
          ListTile(
            title: const TText('Sign out'),
            onTap: () {
              store.put('signedIn', false);
              Navigator.popUntil(c, (r) => r.isFirst);
            },
          ),
          ListTile(
            title: const TText(
              'Delete local account data',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () => showDialog<void>(
              context: c,
              builder: (d) => AlertDialog(
                title: const TText('Delete local account data?'),
                content: const TText(
                  'This removes profile, follows, messages and local activity from this device.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(d),
                    child: const TText('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        for (final item in store.records('pending')) {
                          final path = item['path'];
                          if (path is String && await File(path).exists()) {
                            await File(path).delete();
                          }
                        }
                      } catch (_) {
                        if (d.mounted) {
                          notice(
                            d,
                            'Could not delete data',
                            'Please try again.',
                          );
                        }
                        return;
                      }
                      store.clear();
                      if (d.mounted) Navigator.pop(d);
                      if (c.mounted) Navigator.popUntil(c, (r) => r.isFirst);
                    },
                    child: const TText('Delete'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class Blocked extends StatelessWidget {
  const Blocked({super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: store,
    builder: (c, _) {
      final blocked = store.members
          .where((m) => store.list('blocked').contains(m.id))
          .toList();
      return Screen(
        'Blocked accounts',
        blocked.isEmpty
            ? const Center(child: TText('Your blocked list is empty.'))
            : ListView(
                children: [
                  for (final m in blocked)
                    ListTile(
                      leading: avatar(m.image),
                      title: TText(m.name),
                      trailing: TextButton(
                        onPressed: () => store.toggle('blocked', m.id),
                        child: const TText('Unblock'),
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

class Guidelines extends StatelessWidget {
  const Guidelines({super.key});
  @override
  Widget build(BuildContext c) => const Screen(
    'Community Guidelines',
    SingleChildScrollView(
      padding: EdgeInsets.all(18),
      child: TText(
        'Be real and be respectful\nUse an authentic identity. Do not impersonate others or manipulate follows.\n\nConsent comes first\nMessages and calls require mutual follow. Never pressure someone to follow, reply, meet or share private information.\n\nKeep people safe\nNo bullying, threats, hate speech, sexual exploitation, graphic violence, scams, spam or promotion of dangerous activity.\n\nProtect privacy\nDo not publish another person’s private information, intimate media or location without permission.\n\nUse safety tools\nReport content that violates these rules. Block a person when you do not want to see their profile, content or conversations. Reports and blocks hide affected content on this device.',
      ),
    ),
  );
}

class LiveSetup extends StatefulWidget {
  const LiveSetup({super.key});
  @override
  State<LiveSetup> createState() => _LiveSetupState();
}

class _LiveSetupState extends State<LiveSetup> {
  final title = TextEditingController();
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Screen(
    'Go live',
    ListView(
      padding: const EdgeInsets.all(18),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/art/presence-constellation-field.png',
            height: 190,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 20),
        header('Open a live conversation'),
        const SizedBox(height: 8),
        const TText(
          'Preview your camera and microphone locally. No broadcast service is connected.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: title,
          maxLength: 48,
          decoration: const InputDecoration(labelText: 'Live title'),
        ),
        const SizedBox(height: 20),
        action('Start local preview', () {
          final t = title.text.trim();
          if (t.length < 3 || !allowed(t)) {
            notice(
              c,
              'Name your live',
              'Use a clear title between 3 and 48 characters.',
            );
            return;
          }
          open(c, CreatorPreview(t));
        }, primary: true),
      ],
    ),
  );
}

class CreatorPreview extends StatefulWidget {
  final String title;
  const CreatorPreview(this.title, {super.key});
  @override
  State<CreatorPreview> createState() => _CreatorPreviewState();
}

class _CreatorPreviewState extends State<CreatorPreview>
    with WidgetsBindingObserver {
  CameraController? camera;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    start();
  }

  Future<void> start() async {
    final token = ++generation;
    final previous = camera;
    camera = null;
    await previous?.dispose();
    if (!mounted || token != generation) return;
    try {
      final cameras = await availableCameras();
      if (!mounted || token != generation) return;
      if (cameras.isEmpty) {
        setState(() => error = 'No camera is available.');
        return;
      }
      final selected =
          cameras
              .where((c) => c.lensDirection == CameraLensDirection.front)
              .firstOrNull ??
          cameras.first;
      final next = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      camera = next;
      await next.initialize();
      if (!mounted || token != generation) return;
      setState(() {
        error = null;
      });
    } catch (_) {
      if (mounted && token == generation) {
        setState(
          () => error =
              'Camera or microphone access is unavailable. Check device permissions and try again.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      generation++;
      final old = camera;
      camera = null;
      old?.dispose();
    } else {
      start();
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Screen(
    'Local preview',
    Stack(
      fit: StackFit.expand,
      children: [
        if (camera?.value.isInitialized == true)
          CameraPreview(camera!)
        else
          Center(
            child: TText(
              error ?? 'Opening camera…',
              textAlign: TextAlign.center,
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TText(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const TText('Local preview only · not broadcasting'),
                if (error != null)
                  TextButton(onPressed: start, child: const TText('Try again')),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});
  @override
  Widget build(BuildContext c) => Screen(
    'Choose your language',
    ListView(
      children: [
        for (final entry in const {
          'en': 'English',
          'zh-Hans': '简体中文',
          'es': 'Español',
          'ja': '日本語',
          'de': 'Deutsch',
        }.entries)
          ListTile(
            title: Text(entry.value),
            trailing: store.get('language', 'en') == entry.key
                ? const TText('Selected')
                : null,
            onTap: () {
              store.put('language', entry.key);
            },
          ),
      ],
    ),
  );
}
