import 'dart:io';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:record/record.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'store.dart';
import 'cloud.dart';
import 'social.dart';
import 'rtc.dart';

const termsUrl = String.fromEnvironment(
  'TOTI_TERMS_URL',
  defaultValue: 'https://sites.google.com/view/toti-connect-policies/terms-of-service?hl=en',
);
const privacyUrl = String.fromEnvironment(
  'TOTI_PRIVACY_URL',
  defaultValue: 'https://sites.google.com/view/toti-connect-policies/privacy-policy?hl=en',
);

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
RtcDirectory? rtcDirectory;
final routeObserver = RouteObserver<PageRoute<dynamic>>();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TotiStartup());
}

class TotiStartup extends StatefulWidget {
  const TotiStartup({super.key});

  @override
  State<TotiStartup> createState() => _TotiStartupState();
}

class _TotiStartupState extends State<TotiStartup> {
  bool cloudReady = false;
  late Future<void> initialization;

  @override
  void initState() {
    super.initState();
    initialization = initialize();
  }

  Future<void> initialize() async {
    if (!cloudReady) {
      await TotiCloud.initialize();
      cloudReady = true;
    }
    final nextStore = AppStore();
    try {
      await nextStore.init();
      store = nextStore;
    } catch (_) {
      nextStore.dispose();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: initialization,
    builder: (context, snapshot) {
      final failed =
          snapshot.connectionState == ConnectionState.done && snapshot.hasError;
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return const TotiApp();
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xff07020c),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/art/toti-app-icon.png',
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      semanticLabel: 'Toti',
                    ),
                    const SizedBox(height: 28),
                    if (failed) ...[
                      const Text(
                        'Unable to start Toti. Please try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xfff3d9ec)),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() {
                          initialization = initialize();
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xffff8fd7),
                        ),
                        child: const Text('Try again'),
                      ),
                    ] else
                      SizedBox(
                        width: 96,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            minHeight: 3,
                            color: Color(0xffff39b4),
                            backgroundColor: Color(0xff3b1238),
                            semanticsLabel: 'Loading Toti',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: panel,
          selectedColor: const Color(0xff593286),
          labelStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
          side: BorderSide.none,
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          hintStyle: const TextStyle(color: muted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: panel,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? Colors.white : muted,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? pink : panel2,
          ),
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
Future<void> toggleLike(BuildContext context, String id) async {
  try {
    await store.toggle('likes', id);
  } catch (_) {
    if (context.mounted) {
      notice(
        context,
        'Could not update like',
        'Please check your connection and try again.',
      );
    }
  }
}

Widget photo(String name, {BoxFit fit = BoxFit.cover}) {
  if (name == '__real_user__') {
    return Image.asset('assets/art/profile-orbit-halo.png', fit: fit);
  }
  if (name.startsWith('$totiSupabaseUrl/storage/')) {
    return Image.network(
      name,
      fit: fit,
      errorBuilder: (_, _, _) =>
          Image.asset('assets/art/profile-orbit-halo.png', fit: fit),
    );
  }
  final path = 'assets/portraits/$name';
  return Image.network(
    TotiCloud.mediaUrl(path).toString(),
    fit: fit,
    errorBuilder: (_, _, _) => Container(color: panel2),
  );
}

Widget avatar(String name, {double size = 48}) => ClipOval(
  child: SizedBox(width: size, height: size, child: photo(name)),
);
Widget myAvatar({double size = 48, String? previewPath}) {
  final path = previewPath ?? store.get('avatarPath', '') as String;
  final cloudKey = store.get('avatar_key', null);
  Widget fallback() {
    if (cloudKey is! String || cloudKey.isEmpty)
      return photo('riverside-black-dress.jpg');
    return FutureBuilder<String>(
      future: TotiCloud.avatarUrl(cloudKey),
      builder: (_, snapshot) => snapshot.hasData
          ? Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => photo('riverside-black-dress.jpg'),
            )
          : photo('riverside-black-dress.jpg'),
    );
  }

  return ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: path.isEmpty
          ? fallback()
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            ),
    ),
  );
}

// Each fifth of the original artwork is one pictogram.
Widget spriteArtwork(String asset, int index, {double size = 26}) => SizedBox(
  width: size,
  height: size,
  child: ClipRect(
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: -index * size,
          top: -(size * 5 / 3 - size) / 2,
          child: Image.asset(asset, width: size * 5),
        ),
      ],
    ),
  ),
);
Widget navigationArtwork(int index, {bool selected = false}) => Opacity(
  opacity: selected ? 1 : .62,
  child: spriteArtwork('assets/art/toti-navigation-icons.png', index),
);
Widget actionArtwork(int index, {double size = 22}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-action-icons.png', index, size: size),
);
Widget cardArtwork(int index, {double size = 32}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-card-icons.png', index, size: size),
);
Widget utilityArtwork(int index, {double size = 26}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-utility-icons.png', index, size: size),
);
Widget controlArtwork(int index, {double size = 24}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-control-icons.png', index, size: size),
);
Widget reelArtwork(int index, {double size = 28}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-reel-icons.png', index, size: size),
);
Widget giftArtwork(int index, {double size = 64}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-gift-icons.png', index, size: size),
);
Widget roomToolbarArtwork(int index, {double size = 24}) => ExcludeSemantics(
  child: spriteArtwork(
    'assets/art/toti-room-toolbar-icons.png',
    index,
    size: size,
  ),
);
Widget discoveryArtwork(int index, {double size = 24}) => ExcludeSemantics(
  child: spriteArtwork(
    'assets/art/toti-discovery-icons.png',
    index,
    size: size,
  ),
);
Widget inboxArtwork(int index, {double size = 36}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-inbox-icons.png', index, size: size),
);
Widget memberActionArtwork(int index, {double size = 26}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-member-actions.png', index, size: size),
);
Widget authArtwork(int index, {double size = 24}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-auth-icons.png', index, size: size),
);
Widget coinPackArtwork(int index, {double size = 44}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-coin-packs.png', index, size: size),
);
Widget callArtwork(int index, {double size = 28}) => ExcludeSemantics(
  child: spriteArtwork('assets/art/toti-call-icons.png', index, size: size),
);
Widget iconLabel(Widget icon, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [icon, const SizedBox(width: 6), TText(label)],
);
Widget emptyState(String message, {int artwork = 3}) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        cardArtwork(artwork, size: 64),
        const SizedBox(height: 12),
        TText(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
      ],
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: Color(0xff392552)),
  ),
  clipBehavior: Clip.antiAlias,
  child: Padding(padding: padding, child: child),
);
Widget listCard(Widget child) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: card(child, padding: EdgeInsets.zero),
);

class TotiPressable extends StatefulWidget {
  const TotiPressable({required this.onTap, required this.child, super.key});
  final VoidCallback onTap;
  final Widget child;
  @override
  State<TotiPressable> createState() => _TotiPressableState();
}

class _TotiPressableState extends State<TotiPressable> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onTap,
      onHighlightChanged: (value) => setState(() => pressed = value),
      child: AnimatedScale(
        scale: pressed && !MediaQuery.of(context).disableAnimations ? .98 : 1,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    ),
  );
}

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
          child: iconLabel(controlArtwork(0, size: 16), 'Back'),
        ),
      ),
      leadingWidth: 76,
      title: Semantics(
        label: tr(title),
        header: true,
        child: const SizedBox.shrink(),
      ),
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
  bool entering = false;
  bool registering = false;
  bool showPassword = false;
  bool showingAccount = false;
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  void switchMode(bool value) {
    if (entering) return;
    if (registering == value) return;
    FocusScope.of(context).unfocus();
    password.clear();
    confirmation.clear();
    setState(() {
      registering = value;
      showPassword = false;
    });
  }

  Future<void> enterAccount() async {
    if (entering) return;
    if (!formKey.currentState!.validate()) return;
    if (!accepted) {
      notice(
        context,
        'Agree to continue',
        'Please review and accept the Terms of Service and Privacy Policy.',
      );
      return;
    }
    setState(() => entering = true);
    final creatingAccount = registering;
    try {
      final userId = creatingAccount
          ? await TotiCloud.register(email.text.trim(), password.text)
          : await TotiCloud.signIn(email.text.trim(), password.text);
      if (!mounted) return;
      if (userId == null) {
        password.clear();
        confirmation.clear();
        setState(() {
          entering = false;
          registering = false;
        });
        notice(
          context,
          'Check your email',
          'If registration is available, follow the confirmation link in your email, then sign in.',
        );
        return;
      }
      await store.activateAccount(userId);
      await store.refreshCloudContent();
      await store.restoreCloudProfile();
    } on AuthException {
      if (mounted) {
        setState(() => entering = false);
        notice(
          context,
          'Unable to continue',
          creatingAccount
              ? 'Registration could not be completed. Check your details and try again.'
              : 'Check your email and password, and make sure your email is confirmed.',
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => entering = false);
        notice(
          context,
          'Unable to continue',
          'Please check your connection and try again.',
        );
      }
      return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    email.clear();
    password.clear();
    confirmation.clear();
    store.login();
  }

  InputDecoration authDecoration(String label, int artwork) => InputDecoration(
    labelText: tr(label),
    prefixIcon: Padding(
      padding: const EdgeInsets.all(14),
      child: authArtwork(artwork, size: 24),
    ),
    fillColor: const Color(0xff24163a),
    labelStyle: const TextStyle(color: Color(0xffd8c4df)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  void returnToWelcome() {
    if (entering) return;
    FocusScope.of(context).unfocus();
    setState(() => showingAccount = false);
  }

  Widget agreement(BuildContext c) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        label: tr(
          'I am 18 or older and agree to the Terms of Service and Privacy Policy.',
        ),
        checked: accepted,
        child: InkWell(
          key: const ValueKey('accept-terms'),
          onTap: () => setState(() => accepted = !accepted),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: controlArtwork(accepted ? 1 : 2, size: 28)),
          ),
        ),
      ),
      Expanded(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const TText('I am 18 or older and agree to the '),
            TextButton(
              style: linkStyle,
              onPressed: () =>
                  open(c, const PolicyPage('Terms of Service', termsUrl)),
              child: const TText('Terms of Service'),
            ),
            const TText(' and '),
            TextButton(
              style: linkStyle,
              onPressed: () =>
                  open(c, const PolicyPage('Privacy Policy', privacyUrl)),
              child: const TText('Privacy Policy'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget welcome(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/art/account-entry-scene.png', fit: BoxFit.cover),
          const ColoredBox(color: Color(0x7a10071c)),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 4),
                      const TText(
                        'Toti',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const TText(
                        'Find your people. Share your moments.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xfff7edf4)),
                      ),
                      const Spacer(flex: 5),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('welcome-email'),
                          onPressed: () =>
                              setState(() => showingAccount = true),
                          style: FilledButton.styleFrom(
                            backgroundColor: pink,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 52),
                          ),
                          child: const TText('Continue with email'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      agreement(c),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext c) => PopScope(
    canPop: !showingAccount,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && showingAccount) returnToWelcome();
    },
    child: showingAccount ? accountForm(c) : welcome(c),
  );

  Widget accountForm(BuildContext c) => Scaffold(
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/art/account-entry-scene.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8a10071c),
                  Color(0xf20e061e),
                  Color(0xff0a0220),
                ],
                stops: [0, .46, 1],
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 46).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: entering ? null : returnToWelcome,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0x99301c3e),
                        minimumSize: const Size(48, 44),
                      ),
                      child: iconLabel(controlArtwork(0, size: 18), 'Back'),
                    ),
                    const SizedBox(height: 14),
                    const TText(
                      'Toti',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const TText(
                      'Find your people. Share your moments.',
                      style: TextStyle(color: Color(0xffeee1ea), fontSize: 14),
                    ),
                    SizedBox(
                      height: (constraints.maxHeight * .08).clamp(24.0, 60.0),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: authTab(
                            'Sign in',
                            !registering,
                            () => switchMode(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: authTab(
                            'Register',
                            registering,
                            () => switchMode(true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const TText(
                      'Sign in with your email, or create an account to get started.',
                      style: TextStyle(
                        color: Color(0xffe3cfe0),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            key: const ValueKey('auth-email'),
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [],
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: authDecoration('Email address', 0),
                            validator: (value) {
                              final address = (value ?? '').trim();
                              final valid = RegExp(
                                r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                              ).hasMatch(address);
                              return valid && !address.contains('..')
                                  ? null
                                  : tr('Enter a valid email address.');
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('auth-password'),
                            controller: password,
                            obscureText: !showPassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: const [],
                            textInputAction: registering
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!registering) enterAccount();
                            },
                            decoration:
                                authDecoration(
                                  'Password (6+ characters)',
                                  1,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    tooltip: tr(
                                      showPassword
                                          ? 'Hide password'
                                          : 'Show password',
                                    ),
                                    onPressed: () => setState(
                                      () => showPassword = !showPassword,
                                    ),
                                    icon: authArtwork(
                                      showPassword ? 3 : 2,
                                      size: 23,
                                    ),
                                  ),
                                ),
                            validator: (value) => (value ?? '').length >= 6
                                ? null
                                : tr('Use at least 6 characters.'),
                          ),
                          if (registering) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('auth-confirmation'),
                              controller: confirmation,
                              obscureText: !showPassword,
                              enableSuggestions: false,
                              autocorrect: false,
                              autofillHints: const [],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => enterAccount(),
                              decoration: authDecoration('Confirm password', 1),
                              validator: (value) => value == password.text
                                  ? null
                                  : tr('Passwords do not match.'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: entering ? null : enterAccount,
                        style: FilledButton.styleFrom(
                          backgroundColor: pink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 52),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TText(
                              entering
                                  ? 'Connecting…'
                                  : registering
                                  ? 'Create account'
                                  : 'Sign in',
                            ),
                            const SizedBox(width: 8),
                            authArtwork(4, size: 22),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    agreement(c),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget authTab(String label, bool selected, VoidCallback onTap) => TextButton(
  onPressed: onTap,
  style: TextButton.styleFrom(
    minimumSize: const Size(48, 46),
    backgroundColor: selected
        ? const Color(0xff63316b)
        : const Color(0x99301c3e),
    foregroundColor: selected ? Colors.white : const Color(0xffd4c4d2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  child: TText(label),
);

class PolicyPage extends StatefulWidget {
  final String title, url;
  const PolicyPage(this.title, this.url, {super.key});
  @override
  State<PolicyPage> createState() => _PolicyPageState();
}

class _PolicyPageState extends State<PolicyPage> {
  WebViewController? controller;
  Uri? policyUri;
  String? currentUrl;
  bool loading = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      policyUri = uri;
      loading = true;
      initializeWebView(uri);
    }
  }

  Future<void> initializeWebView(Uri uri) async {
    try {
      final web = WebViewController();
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (Uri.tryParse(request.url)?.scheme == 'https') {
              return NavigationDecision.navigate;
            }
            if (request.isMainFrame && mounted) {
              setState(() {
                failed = true;
                loading = false;
              });
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            currentUrl = url;
            if (mounted) {
              setState(() {
                loading = true;
                failed = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => loading = false);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                failed = true;
                loading = false;
              });
            }
          },
          onHttpError: (error) {
            if (mounted &&
                currentUrl != null &&
                error.request?.uri.toString() == currentUrl) {
              setState(() {
                failed = true;
                loading = false;
              });
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() => controller = web);
      await web.loadRequest(uri);
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  Future<void> retry() async {
    if (policyUri == null) return;
    setState(() {
      failed = false;
      loading = true;
    });
    try {
      if (controller == null) {
        await initializeWebView(policyUri!);
      } else {
        await controller!.loadRequest(policyUri!);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  Future<void> back() async {
    if (controller != null && !failed && await controller!.canGoBack()) {
      await controller!.goBack();
      return;
    }
    if (mounted) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
            child: Row(
              children: [
                memberIconButton(label: 'Back', artwork: 0, onTap: back),
                const SizedBox(width: 12),
                Expanded(
                  child: TText(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: policyUri == null
                ? const Center(
                    child: TText('This policy is currently unavailable.'),
                  )
                : failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TText('Unable to open this policy.'),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: retry,
                          child: const TText('Try again'),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      if (controller != null)
                        WebViewWidget(controller: controller!),
                      if (loading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
          ),
        ],
      ),
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
  bool incomingCallVisible = false;
  final Set<String> handledCalls = {};

  @override
  void initState() {
    super.initState();
    final userId = store.activeUserId;
    if (userId != null) {
      final directory = RtcDirectory(userId);
      rtcDirectory = directory;
      directory.addListener(checkIncomingCall);
      directory.start();
    }
    if (store.get('welcomeShown', false) != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        store.put('welcomeShown', true);
        showDialog<void>(
          context: context,
          builder: (c) => Dialog(
            backgroundColor: const Color(0xff1b0b36),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: .94, end: 1),
                      duration: MediaQuery.of(c).disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: ExcludeSemantics(
                        child: Image.asset(
                          'assets/art/toti-welcome-gift.png',
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const TText(
                      'Welcome to Toti',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        color: Color(0xfffff5fb),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const TText(
                      'Your first login gift',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xffddc8e3), fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    const TText(
                      '+888',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        height: 1.05,
                        color: Color(0xffffb1dc),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const TText(
                      'Coins',
                      style: TextStyle(color: Color(0xffe6d5e9), fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(c),
                        style: FilledButton.styleFrom(
                          backgroundColor: pink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 52),
                        ),
                        child: const TText('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      });
    }
  }

  void checkIncomingCall() {
    final directory = rtcDirectory;
    if (!mounted || directory == null || incomingCallVisible) return;
    for (final session in directory.sessions) {
      final id = session['id'];
      if (id is! String ||
          handledCalls.contains(id) ||
          session['peer_id'] != directory.userId ||
          session['status'] != 'ringing')
        continue;
      incomingCallVisible = true;
      handledCalls.add(id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showIncomingCall(session);
      });
      break;
    }
  }

  Future<void> showIncomingCall(Map<String, dynamic> session) async {
    final directory = rtcDirectory;
    if (directory == null) return;
    final owner = session['owner_id'] as String;
    final id = session['id'] as String;
    final member = store.members.where((m) => m.authId == owner).firstOrNull;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: TText(
          session['kind'] == 'video_call' ? 'Video call' : 'Voice call',
        ),
        content: TText('${member?.name ?? 'Someone'} is calling you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const TText('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const TText('Accept'),
          ),
        ],
      ),
    );
    try {
      await directory.update(id, accepted == true ? 'accept' : 'decline');
      if (accepted == true && mounted) {
        open(context, RtcSessionPage(session));
      }
    } catch (_) {
      if (mounted && accepted == true) {
        notice(
          context,
          'Call unavailable',
          'The call has ended or could not be connected.',
        );
      }
    } finally {
      incomingCallVisible = false;
      if (mounted) checkIncomingCall();
    }
  }

  @override
  void dispose() {
    final directory = rtcDirectory;
    rtcDirectory = null;
    directory?.removeListener(checkIncomingCall);
    directory?.dispose();
    super.dispose();
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: MediaQuery.of(c).disableAnimations
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              width: 48,
                              height: 32,
                              decoration: BoxDecoration(
                                color: i == tab
                                    ? const Color(0xff4a1c62)
                                    : Colors.transparent,
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
                                  color: i == tab
                                      ? const Color(0xffffb0de)
                                      : muted,
                                  fontWeight: i == tab
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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

Widget discoveryIconButton(
  String label,
  int artwork,
  VoidCallback onTap, {
  bool primary = false,
  Color? background,
}) => Tooltip(
  message: tr(label),
  child: Semantics(
    button: true,
    label: tr(label),
    child: Material(
      color: primary ? pink : (background ?? Colors.transparent),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: discoveryArtwork(artwork)),
        ),
      ),
    ),
  ),
);

class DiscoverySearchDialog extends StatefulWidget {
  const DiscoverySearchDialog({required this.initialQuery, super.key});
  final String initialQuery;
  @override
  State<DiscoverySearchDialog> createState() => _DiscoverySearchDialogState();
}

class _DiscoverySearchDialogState extends State<DiscoverySearchDialog> {
  late final TextEditingController field;
  @override
  void initState() {
    super.initState();
    field = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Dialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              discoveryArtwork(0, size: 36),
              const SizedBox(width: 12),
              const Expanded(
                child: TText(
                  'Find someone',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              discoveryIconButton('Close search', 4, () => Navigator.pop(c)),
            ],
          ),
          const SizedBox(height: 8),
          const TText(
            'Search the community by display name.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: field,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => Navigator.pop(c, field.text.trim()),
            decoration: InputDecoration(hintText: tr('Type a name')),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(c, ''),
                child: const TText('Reset'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: action(
                  'Show results',
                  () => Navigator.pop(c, field.text.trim()),
                  primary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class Discover extends StatefulWidget {
  const Discover({super.key});
  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  String category = 'All', region = 'Global', query = '';
  @override
  void initState() {
    super.initState();
    store.addListener(_changed);
    rtcDirectory?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_changed);
    rtcDirectory?.removeListener(_changed);
    super.dispose();
  }

  Map<String, dynamic>? liveSession(Member member) {
    if (member.authId == null) return null;
    return rtcDirectory?.sessions
        .where(
          (session) =>
              session['kind'] == 'live' &&
              session['status'] == 'active' &&
              session['owner_id'] == member.authId,
        )
        .firstOrNull;
  }

  static const regions = [
    'Global',
    'Europe',
    'Asia',
    'Latin',
    'India',
    'MENA',
    'Africa',
    'North America',
    'Oceania',
  ];
  Future<void> searchPeople() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => DiscoverySearchDialog(initialQuery: query),
    );
    if (mounted && result != null) setState(() => query = result);
  }

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
                  (category == 'Live' && (m.live || liveSession(m) != null)) ||
                  (category == 'Follow' &&
                      store.list('following').contains(m.id))) &&
              (region == 'Global' || m.region == region) &&
              m.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        if (store.social?.error != null)
          TextButton(
            onPressed: () => store.social?.retry(),
            child: TText(store.social!.error!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (final t in ['All', 'Live', 'New', 'Follow'])
                      Expanded(
                        child: Semantics(
                          selected: category == t,
                          child: SizedBox(
                            height: 44,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: category == t
                                          ? Colors.white
                                          : muted,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 44),
                                    ),
                                    onPressed: () =>
                                        setState(() => category = t),
                                    child: TText(
                                      t,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: category == t
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                if (category == t)
                                  IgnorePointer(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        width: 21,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: pink,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              discoveryIconButton(
                'Search people',
                0,
                searchPeople,
                background: query.isEmpty ? null : panel2,
              ),
              discoveryIconButton(
                'Boutique',
                1,
                () => open(c, const Boutique()),
              ),
              discoveryIconButton(
                'Create',
                2,
                () => createMenu(c),
                primary: true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(7, 2, 6, 0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final r in regions)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: Semantics(
                            selected: region == r,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: region == r
                                    ? pink.withValues(alpha: .30)
                                    : Colors.white.withValues(alpha: .07),
                                foregroundColor: region == r
                                    ? Colors.white
                                    : const Color(0xffd2c6d9),
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: region == r
                                      ? const BorderSide(color: pink, width: .8)
                                      : BorderSide.none,
                                ),
                              ),
                              onPressed: () => setState(() => region = r),
                              child: TText(
                                r,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              discoveryIconButton(
                'Use my region',
                3,
                locate,
                background: const Color(0xff7029f2).withValues(alpha: .48),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(10, 2, 10, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TText(
              'Example profiles',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ),
        ),
        Expanded(
          child: members.isEmpty
              ? emptyState('No profiles found', artwork: 1)
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
                      final live = liveSession(m);
                      return TotiPressable(
                        onTap: () => live != null
                            ? open(c, RtcSessionPage(live))
                            : m.live
                            ? open(c, LiveRoom(m))
                            : open(c, MemberPage(m)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
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
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: bg.withValues(alpha: .7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: actionArtwork(4, size: 18),
                                ),
                              ),
                              Positioned(
                                left: 10,
                                right: 10,
                                bottom: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m.live || live != null)
                                      const TText(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.pinkAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    TText(
                                      '${m.name}, ${m.age}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    TText(
                                      '${m.country}  ${m.region}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            children: [
              SizedBox(
                height: (MediaQuery.sizeOf(c).height * .51).clamp(300.0, 460.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    photo(member.image),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x660b0417),
                            Colors.transparent,
                            Color(0xe6000010),
                          ],
                          stops: [0, .48, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 14,
                      child: memberIconButton(
                        label: 'Back',
                        artwork: 0,
                        onTap: () => Navigator.maybePop(c),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 14,
                      child: memberIconButton(
                        label: 'Report or block',
                        artwork: 4,
                        onTap: () => safety(c, 'profile:${member.id}', member),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TText(
                            '${member.name}, ${member.age}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TText(
                            '${member.country}  ${member.region}',
                            style: const TextStyle(
                              color: Color(0xffe1d9e8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TText(
                      'About',
                      style: TextStyle(
                        color: Color(0xffc6b4d4),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TText(
                      member.bio,
                      style: const TextStyle(fontSize: 15, height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    const TText(
                      'Interests',
                      style: TextStyle(
                        color: Color(0xffc6b4d4),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: member.interests
                          .map(
                            (interest) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xff251444),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(0xff49305e),
                                ),
                              ),
                              child: TText(
                                interest,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    TText(
                      member.doorway,
                      style: const TextStyle(color: muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: memberActionButton(
                    label: following ? 'Following' : 'Follow',
                    artwork: following ? 2 : 1,
                    primary: !following,
                    onTap: () async {
                      try {
                        await store.toggle('following', member.id);
                      } catch (_) {
                        if (c.mounted)
                          notice(
                            c,
                            'Could not update follow',
                            'Please try again.',
                          );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: memberActionButton(
                    label: 'Message',
                    artwork: 3,
                    onTap: () {
                      if (!store.mutual(member)) {
                        notice(
                          c,
                          'Mutual follow required',
                          'You and ${member.name} must both follow each other before messaging.',
                        );
                        return;
                      }
                      open(c, Conversation(member));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                memberCallButton(
                  label: 'Voice call',
                  artwork: 0,
                  onTap: () => openMemberCall(c, member, video: false),
                ),
                const SizedBox(width: 8),
                memberCallButton(
                  label: 'Video call',
                  artwork: 1,
                  onTap: () => openMemberCall(c, member, video: true),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

final Set<String> pendingRtcCalls = {};

Future<void> openMemberCall(
  BuildContext context,
  Member member, {
  required bool video,
}) async {
  if (!store.mutual(member)) {
    notice(
      context,
      'Mutual follow required',
      'Both people must follow each other.',
    );
    return;
  }
  final peerId = member.authId;
  if (peerId == null) {
    open(context, CallPreview(member, video: video));
    return;
  }
  final directory = rtcDirectory;
  if (directory == null || !pendingRtcCalls.add(peerId)) return;
  try {
    final session = await directory.startSession(
      kind: video ? 'video_call' : 'voice_call',
      peerId: peerId,
    );
    if (context.mounted) {
      open(context, RtcSessionPage(session));
    } else {
      await directory.update(session['id'] as String, 'end');
    }
  } catch (_) {
    if (context.mounted) {
      notice(
        context,
        'Call unavailable',
        'Please check your connection and try again.',
      );
    }
  } finally {
    pendingRtcCalls.remove(peerId);
  }
}

Widget memberCallButton({
  required String label,
  required int artwork,
  required VoidCallback onTap,
}) => Tooltip(
  message: tr(label),
  child: Semantics(
    button: true,
    label: tr(label),
    child: Material(
      color: const Color(0xff38204d),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 54,
          child: Center(child: callArtwork(artwork, size: 30)),
        ),
      ),
    ),
  ),
);

Widget memberIconButton({
  required String label,
  required int artwork,
  required VoidCallback onTap,
}) => Tooltip(
  message: tr(label),
  child: Semantics(
    button: true,
    label: tr(label),
    child: Material(
      color: const Color(0xff1b102c).withValues(alpha: .78),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(child: memberActionArtwork(artwork, size: 24)),
        ),
      ),
    ),
  ),
);

Widget memberActionButton({
  required String label,
  required int artwork,
  required VoidCallback onTap,
  bool primary = false,
}) => TextButton(
  style: TextButton.styleFrom(
    backgroundColor: primary ? pink : const Color(0xff2c164d),
    foregroundColor: Colors.white,
    minimumSize: const Size(48, 54),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  onPressed: onTap,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      memberActionArtwork(artwork, size: 25),
      const SizedBox(width: 7),
      Flexible(
        child: TText(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  ),
);

void safety(BuildContext c, String id, Member? member) {
  showModalBottomSheet(
    context: c,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: utilityArtwork(2),
            title: const TText('Report content'),
            onTap: () {
              Navigator.pop(ctx);
              report(c, id, member);
            },
          ),
          if (member != null)
            ListTile(
              leading: utilityArtwork(2),
              title: TText('Block ${member.name}'),
              onTap: () {
                Navigator.pop(ctx);
                showDialog<void>(
                  context: c,
                  builder: (d) => AlertDialog(
                    title: TText('Block ${member.name}?'),
                    content: const TText(
                      'Their profile and activity will be hidden from your view.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d),
                        child: const TText('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await store.block(member);
                          } catch (_) {
                            if (d.mounted)
                              notice(
                                d,
                                'Could not block account',
                                'Please try again.',
                              );
                            return;
                          }
                          if (!d.mounted || !c.mounted) return;
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
              onTap: () async {
                final reporter = store.activeUserId;
                try {
                  await TotiCloud.submitReport(id, member?.id, reason);
                } catch (_) {
                  if (ctx.mounted) {
                    notice(
                      ctx,
                      'Could not submit report',
                      'Please check your connection and try again.',
                    );
                  }
                  return;
                }
                if (!ctx.mounted ||
                    !c.mounted ||
                    reporter == null ||
                    store.activeUserId != reporter)
                  return;
                store.addRecord('reports', {
                  'id': id,
                  'user': member?.id,
                  'reason': reason,
                });
                Navigator.pop(ctx);
                notice(
                  c,
                  'Report submitted',
                  'Your report was submitted. The reported content is hidden from your view.',
                );
              },
            ),
        ],
      ),
    ),
  );
}

class ReelAction extends StatelessWidget {
  const ReelAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    super.key,
  });
  final String label;
  final int icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tr(label),
    child: Semantics(
      button: true,
      label: tr(label),
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xff642253).withValues(alpha: .92)
                  : const Color(0xff170b2c).withValues(alpha: .82),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
            ),
            child: reelArtwork(icon),
          ),
        ),
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

  List<dynamic> get reels {
    final source = store.data['reels'] as List;
    final ordered = List<dynamic>.of(source);
    if (ordered.length >= 3) {
      final first = ordered[0];
      ordered[0] = ordered[2];
      ordered[2] = first;
    }
    return ordered.where((r) {
      final i = source.indexOf(r);
      return !store.list('blocked').contains('member-$i') &&
          !store.records('reports').any((x) => x['id'] == 'reel:${r['video']}');
    }).toList();
  }

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
    final path = 'assets/videos/$loadedVideo';
    final p = VideoPlayerController.networkUrl(TotiCloud.mediaUrl(path));
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
    if (reels.isEmpty) return emptyState('No videos available', artwork: 1);
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
        final videoCover = r['thumbnail'] as String;
        final id = 'reel:${r['video']}';
        final liked = store.list('likes').contains(id);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (i == index && player?.value.isInitialized == true)
              Semantics(
                button: true,
                label: tr(paused ? 'Resume video' : 'Pause video'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
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
                ),
              )
            else
              photo(videoCover),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
            if (i == index && paused)
              Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bg.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        reelArtwork(4, size: 25),
                        const SizedBox(width: 8),
                        const TText(
                          'Paused · Tap to resume',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 12,
              right: 14,
              child: liveControl(
                'Report',
                reelArtwork(0, size: 23),
                () => safety(c, id, m),
              ),
            ),
            Positioned(
              left: 18,
              right: 100,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => open(c, MemberPage(m)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: TText(
                            '@${m.name.toLowerCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 5),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        actionArtwork(4, size: 17),
                      ],
                    ),
                  ),
                  TText(
                    r['caption'],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: tr('View profile'),
                    child: TotiPressable(
                      onTap: () => open(c, MemberPage(m)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .9),
                            width: 2,
                          ),
                        ),
                        child: avatar(m.image, size: 46),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ReelAction(
                    label: liked ? 'Liked' : 'Like',
                    icon: liked ? 2 : 1,
                    selected: liked,
                    onTap: () => toggleLike(c, id),
                  ),
                  const SizedBox(height: 8),
                  ReelAction(
                    label: 'Comments',
                    icon: 3,
                    onTap: () => showComments(c, id),
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

void showComments(BuildContext context, String id) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final media = MediaQuery.of(context);
      final available =
          media.size.height - media.padding.top - media.viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(height: available * .76, child: Comments(id)),
      );
    },
  );
}

class Comments extends StatefulWidget {
  final String id;
  const Comments(this.id, {super.key});
  @override
  State<Comments> createState() => _CommentsState();
}

class _CommentsState extends State<Comments> {
  final field = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;
  String? pendingText, pendingId;
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
    scroll.dispose();
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
    return Material(
      color: const Color(0xff130a29),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
              child: Row(
                children: [
                  const TText(
                    'Comments',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  TText(
                    '${comments.length}',
                    style: const TextStyle(
                      color: Color(0xffff9bd8),
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  discoveryIconButton('Close', 4, () => Navigator.pop(c)),
                ],
              ),
            ),
            Expanded(
              child: comments.isEmpty
                  ? emptyState('No comments yet', artwork: 2)
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final e = comments[index];
                        final member = store.members
                            .where((m) => m.id == e['member'])
                            .firstOrNull;
                        final isMine = e['member'] == null;
                        final author = e['author'] as String? ?? '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (member != null)
                                avatar(member.image, size: 42)
                              else if (isMine)
                                myAvatar(size: 42)
                              else
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: panel2,
                                    shape: BoxShape.circle,
                                  ),
                                  child: TText(
                                    author.isNotEmpty
                                        ? author.characters.first.toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TText(
                                      author,
                                      style: const TextStyle(
                                        color: Color(0xffc9b8d5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    TText(
                                      e['text'] as String? ?? '',
                                      style: const TextStyle(
                                        color: Color(0xfff4ecf6),
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              memberIconButton(
                                label: 'Report',
                                artwork: 4,
                                onTap: () => safety(
                                  c,
                                  'comment:${e['id'] ?? e['text']}',
                                  member,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  myAvatar(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: field,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: InputDecoration(
                        hintText: tr('Write a message'),
                        filled: true,
                        fillColor: panel2,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: pink,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: send,
                    child: const TText('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> send() async {
    if (sending) return;
    final t = field.text.trim();
    if (!allowed(t)) {
      notice(
        context,
        'Comment not sent',
        'Please enter a clear, safe message.',
      );
      return;
    }
    final remote = store.social;
    if (remote == null) {
      notice(
        context,
        'Comment not sent',
        'Please check your connection and try again.',
      );
      return;
    }
    if (pendingText != t) {
      pendingText = t;
      pendingId = SocialStore.newMessageId();
    }
    setState(() => sending = true);
    try {
      await remote
          .sendComment(widget.id, t, pendingId!)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (field.text.trim() == t) field.clear();
      pendingText = null;
      pendingId = null;
    } catch (_) {
      if (mounted)
        notice(
          context,
          'Comment not sent',
          'Please check your connection and try again.',
        );
      return;
    } finally {
      if (mounted) setState(() => sending = false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.jumpTo(scroll.position.maxScrollExtent);
    });
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
          ),
        ),
      ),
      const SizedBox(width: 8),
      TextButton(
        style: TextButton.styleFrom(
          backgroundColor: pink,
          foregroundColor: Colors.white,
        ),
        onPressed: send,
        child: const TText('Send'),
      ),
    ],
  ),
);

const roomSeeds = <Map<String, dynamic>>[
  {
    'id': 'glow-after-dark',
    'title': 'Glow After Dark',
    'summary': 'Music · stories · easy company',
    'host': '0',
    'cover': 'room-stills/night-skyline-chat.jpg',
    'tag': 'Featured',
    'audience': 'English',
    'guests': [0, 3, 5],
  },
  {
    'id': 'city-pop-lounge',
    'title': 'City Pop Lounge',
    'summary': 'Live playlist',
    'host': '6',
    'cover': 'room-stills/street-style-live.jpg',
    'tag': 'Music',
    'audience': 'Spain',
    'guests': [6, 7, 9],
  },
  {
    'id': 'coffee-good-news',
    'title': 'Coffee & Good News',
    'summary': 'English room',
    'host': '10',
    'cover': 'room-stills/rooftop-food-live.jpg',
    'tag': 'Conversation',
    'audience': 'English',
    'guests': [10, 11, 15],
  },
  {
    'id': 'game-night',
    'title': 'Game Night',
    'summary': 'Friendly challenges',
    'host': '17',
    'cover': 'room-stills/city-dance-corner.jpg',
    'tag': 'Games',
    'audience': 'India',
    'guests': [17, 18, 19],
  },
  {
    'id': 'travel-postcards',
    'title': 'Travel Postcards',
    'summary': 'Share your favorite view',
    'host': '21',
    'cover': 'room-stills/friends-city-walk.jpg',
    'tag': 'Travel',
    'audience': 'Turkey',
    'guests': [21, 22, 23],
  },
  {
    'id': 'late-night-cinema',
    'title': 'Late Night Cinema',
    'summary': "Tonight's watch list",
    'host': '27',
    'cover': 'room-stills/courtyard-dance-live.jpg',
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

Widget roomToolbarAction(
  String label,
  int artwork,
  VoidCallback onTap, {
  bool primary = false,
}) => Tooltip(
  message: tr(label),
  child: Semantics(
    button: true,
    label: tr(label),
    child: Material(
      color: primary ? pink : panel2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: roomToolbarArtwork(artwork)),
        ),
      ),
    ),
  ),
);

class _RoomsState extends State<Rooms> {
  String query = '', tab = 'Party', audience = 'All';
  static const audiences = [
    'All',
    'English',
    'Spain',
    'India',
    'Turkey',
    'China',
  ];

  @override
  void initState() {
    super.initState();
    rtcDirectory?.addListener(refreshRooms);
  }

  void refreshRooms() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    rtcDirectory?.removeListener(refreshRooms);
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final editorialRooms =
        ((store.data['editorialRooms'] as List?) ?? roomSeeds)
            .map((room) => Map<String, dynamic>.from(room as Map))
            .toList();
    var rooms = [...store.records('rooms'), ...editorialRooms].where((r) {
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
    final liveRooms = (rtcDirectory?.sessions ?? []).where((session) {
      final kind = session['kind'];
      final owner = session['owner_id'];
      return (kind == 'voice_room' || kind == 'live') &&
          session['status'] == 'active' &&
          (tab != 'Follow' ||
              store.list('following').contains('user:$owner')) &&
          audience == 'All' &&
          ('${session['title']} ${session['summary']}'.toLowerCase().contains(
            query.toLowerCase(),
          ));
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      for (final t in ['Party', 'Follow', 'Recent'])
                        Expanded(
                          child: Semantics(
                            selected: tab == t,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: tab == t
                                    ? const Color(0xff593286)
                                    : Colors.transparent,
                                foregroundColor: tab == t
                                    ? Colors.white
                                    : const Color(0xffc5b7d0),
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              onPressed: () => setState(() => tab = t),
                              child: TText(
                                t,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              roomToolbarAction('Store', 0, () => open(c, const Boutique())),
              const SizedBox(width: 6),
              roomToolbarAction(
                'Create',
                1,
                () => open(c, const RoomEditor()),
                primary: true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: tr('Search rooms'),
                    filled: true,
                    fillColor: panel,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ExcludeSemantics(
                        child: Image.asset(
                          'assets/art/toti-search.png',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 116,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Tooltip(
                    message: tr('Room filter'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: audience,
                        isExpanded: true,
                        menuWidth: 180,
                        dropdownColor: panel2,
                        borderRadius: BorderRadius.circular(14),
                        icon: roomToolbarArtwork(2, size: 20),
                        selectedItemBuilder: (context) => [
                          for (final a in audiences)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TText(
                                a,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                        items: [
                          for (final a in audiences)
                            DropdownMenuItem(value: a, child: TText(a)),
                        ],
                        onChanged: (value) =>
                            setState(() => audience = value ?? 'All'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rooms.isEmpty && liveRooms.isEmpty
              ? emptyState('No rooms found')
              : LayoutBuilder(
                  builder: (c, box) {
                    final columns = box.maxWidth >= 700 ? 3 : 2;
                    final width =
                        (box.maxWidth - 28 - (columns - 1) * 10) / columns;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                      children: [
                        if (liveRooms.isNotEmpty) ...[
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final session in liveRooms)
                                realRoomTile(c, session, width, 198),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (rooms.isNotEmpty) ...[
                          roomTile(c, rooms.first, box.maxWidth - 28, 172),
                          const SizedBox(height: 10),
                        ],
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

  Widget realRoomTile(
    BuildContext c,
    Map<String, dynamic> session,
    double width,
    double height,
  ) {
    final owner = store.members
        .where((member) => member.authId == session['owner_id'])
        .firstOrNull;
    return SizedBox(
      width: width,
      height: height,
      child: TotiPressable(
        onTap: () => open(c, RtcSessionPage(session)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (owner != null)
                photo(owner.image)
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
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: pink,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: TText(
                    session['kind'] == 'live' ? 'LIVE' : 'Voice room',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TText(
                      session['title'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TText(
                      owner?.name ?? 'Toti member',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if ((session['summary'] as String? ?? '').isNotEmpty)
                      TText(
                        session['summary'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
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
      child: TotiPressable(
        onTap: () => open(c, RoomPage(room)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width - 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pink,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: spriteArtwork(
                            'assets/art/toti-navigation-icons.png',
                            2,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: TText(
                            room['tag'] ?? 'Room',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

class RoomEditor extends StatefulWidget {
  const RoomEditor({super.key});
  @override
  State<RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<RoomEditor> {
  final title = TextEditingController(), summary = TextEditingController();
  String topic = 'Conversation';
  bool creating = false;
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
        action('Create room', () async {
          if (creating) return;
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
          final directory = rtcDirectory;
          if (directory == null) return;
          setState(() => creating = true);
          try {
            final session = await directory.startSession(
              kind: 'voice_room',
              title: title.text.trim(),
              summary: summary.text.trim(),
              tag: topic,
            );
            if (!mounted || !c.mounted) {
              await directory.update(session['id'] as String, 'end');
              return;
            }
            await Navigator.of(c).pushReplacement(
              MaterialPageRoute(builder: (_) => RtcSessionPage(session)),
            );
          } catch (_) {
            if (mounted && c.mounted) {
              notice(
                c,
                'Room unavailable',
                'Please check your connection and try again.',
              );
            }
          } finally {
            if (mounted) setState(() => creating = false);
          }
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

class VoiceRoomControl extends StatelessWidget {
  const VoiceRoomControl({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    super.key,
  });
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xff7c2567)
                    : const Color(0xff28123e),
                borderRadius: BorderRadius.circular(15),
              ),
              child: icon,
            ),
            const SizedBox(height: 5),
            TText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
  int mySeat = 7;
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

  Future<void> toggleMic({int? requestedSeat}) async {
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
        if (requestedSeat != null) mySeat = requestedSeat;
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

  Widget stageSeat(
    BuildContext c,
    double width, {
    Member? member,
    bool host = false,
    bool mine = false,
    bool available = false,
    required int seatIndex,
  }) {
    final label =
        member?.name ??
        (mine ? store.get('nickname', 'You') as String : 'Open');
    final VoidCallback? openSeat = member != null
        ? () => open(c, MemberPage(member))
        : available
        ? () {
            if (onStage) {
              setState(() => mySeat = seatIndex);
            } else {
              toggleMic(requestedSeat: seatIndex);
            }
          }
        : null;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: const Color(0xff3b2051).withValues(alpha: .8),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: openSeat,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 58,
                height: 58,
                child: member != null
                    ? avatar(member.image, size: 58)
                    : mine
                    ? myAvatar(size: 58)
                    : Center(child: utilityArtwork(0, size: 27)),
              ),
            ),
          ),
          const SizedBox(height: 5),
          TText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          TText(
            host
                ? 'Host'
                : mine
                ? (micActive ? 'Mic on' : 'Muted')
                : member != null
                ? 'Example'
                : 'Seat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xffd8bfda), fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final id = 'room:${widget.room['id'] ?? widget.room['title']}';
    final hostIndex = int.tryParse('${widget.room['host']}') ?? 0;
    final host = store.members[hostIndex];
    final guestIndices = (widget.room['guests'] as List? ?? [hostIndex])
        .whereType<int>()
        .where(
          (i) =>
              i >= 0 &&
              i < store.members.length &&
              i != hostIndex &&
              !store.list('blocked').contains('member-$i'),
        )
        .toList();
    final stageMembers = [
      host,
      for (final i in guestIndices) store.members[i],
    ].take(7).toList();
    final messages = store
        .records('roomMessages')
        .where((e) => e['room'] == id)
        .toList()
        .reversed;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/toti-voice-room-background.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      liveControl(
                        'Back',
                        controlArtwork(0, size: 22),
                        () => Navigator.maybePop(c),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TText(
                              widget.room['title'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TText(
                              widget.room['summary'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xffdbc9dd),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      liveControl(
                        'Report',
                        reelArtwork(0, size: 23),
                        () => safety(c, id, host),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    children: [
                      Material(
                        color: const Color(0xff251038).withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => open(c, MemberPage(host)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                avatar(host.image, size: 46),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TText(
                                        'Host: ${host.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      const TText(
                                        'Audio is unavailable; messages are not shared.',
                                        style: TextStyle(
                                          color: Color(0xffdcc9df),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                actionArtwork(4, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const TText(
                        'Example seats',
                        style: TextStyle(
                          color: Color(0xffe2cee5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final seatWidth = constraints.maxWidth / 4;
                          return Wrap(
                            runSpacing: 16,
                            children: [
                              for (var i = 0; i < 8; i++)
                                stageSeat(
                                  c,
                                  seatWidth,
                                  member: i < stageMembers.length
                                      ? stageMembers[i]
                                      : null,
                                  host: i == 0,
                                  mine: i == mySeat && onStage,
                                  available:
                                      i >= stageMembers.length &&
                                      !(i == mySeat && onStage),
                                  seatIndex: i,
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xff160a29).withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TText(
                              'Room chat',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (messages.isEmpty)
                              const TText(
                                'Say hello to the room',
                                style: TextStyle(color: Color(0xffcdb9d1)),
                              )
                            else
                              for (final message in messages)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Wrap(
                                    children: [
                                      TText(
                                        '${message['author']}: ',
                                        style: const TextStyle(
                                          color: Color(0xffffaeda),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TText(
                                        activityText(message['text'] as String),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: VoiceRoomControl(
                          label: micActive
                              ? 'Mute'
                              : onStage
                              ? 'Unmute'
                              : 'Join stage',
                          icon: utilityArtwork(0, size: 25),
                          active: micActive,
                          onTap: () => toggleMic(),
                        ),
                      ),
                      Expanded(
                        child: VoiceRoomControl(
                          label: 'Members',
                          icon: navigationArtwork(2, selected: true),
                          onTap: () => showRoomMembers(c, widget.room),
                        ),
                      ),
                      Expanded(
                        child: VoiceRoomControl(
                          label: 'Gifts',
                          icon: giftArtwork(4, size: 32),
                          onTap: () async {
                            await showGifts(c, id);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                      Expanded(
                        child: VoiceRoomControl(
                          label: 'Report',
                          icon: reelArtwork(0, size: 24),
                          onTap: () => safety(c, id, host),
                        ),
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
          ),
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
          const ListTile(
            title: TText('Example members'),
            subtitle: TText('These profiles are examples.'),
          ),
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

Future<String?> showGifts(
  BuildContext context,
  String roomId, {
  bool showReceipt = true,
}) async {
  const gifts = [
    ['Rose', 25],
    ['Kiss', 60],
    ['Crown', 180],
    ['Rocket', 520],
  ];
  final selected = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TText(
              'Choose a gift',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const TText(
              'Example gifts are not delivered to another person.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < gifts.length; i++)
                    SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: Material(
                        color: panel2,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            final gift = gifts[i];
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
                              'text': 'Selected ${gift[0]} as an example gift',
                            });
                            store.state['roomMessages'] = records;
                            store.save();
                            Navigator.pop(sheet, gift[0] as String);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                giftArtwork(i, size: 64),
                                TText(
                                  gifts[i][0] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TText(
                                  '${gifts[i][1]} coins',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (selected != null && showReceipt && context.mounted) {
    notice(
      context,
      'Gift selected',
      'This example gift is visible only to you.',
    );
  }
  return selected;
}

class LiveRoom extends StatefulWidget {
  final Member member;
  const LiveRoom(this.member, {super.key});
  @override
  State<LiveRoom> createState() => _LiveRoomState();
}

Widget liveControl(String label, Widget icon, VoidCallback onTap) => Tooltip(
  message: tr(label),
  child: Semantics(
    button: true,
    label: tr(label),
    child: Material(
      color: const Color(0xff160c29).withValues(alpha: .78),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Center(child: icon)),
      ),
    ),
  ),
);

String activityText(String text) =>
    text.replaceAll(' as a local gift', ' as an example gift');

class _LiveRoomState extends State<LiveRoom>
    with WidgetsBindingObserver, RouteAware {
  bool routeVisible = true;
  bool appActive = true;
  Timer? eventTimer;
  Timer? sampleTimer;
  String? eventText;
  int? eventGift;
  int eventSerial = 0;
  int sampleCursor = 2;
  final List<int> visibleSamples = [0, 1];

  static const sampleActivity = <({String text, int? gift})>[
    (text: 'What a view!', gift: null),
    (text: 'Rose', gift: 0),
    (text: 'Love this moment', gift: null),
    (text: 'Crown', gift: 2),
    (text: 'This is beautiful', gift: null),
    (text: 'Rocket', gift: 3),
  ];

  void showEvent(String text, {int? gift}) {
    eventTimer?.cancel();
    setState(() {
      eventText = text;
      eventGift = gift;
      eventSerial++;
    });
    eventTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => eventText = null);
    });
  }

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
    sampleTimer = Timer.periodic(const Duration(milliseconds: 5500), (_) {
      if (!mounted || !routeVisible || !appActive) return;
      setState(() {
        visibleSamples.removeAt(0);
        visibleSamples.add(sampleCursor % sampleActivity.length);
        sampleCursor++;
      });
    });
    loadVideo();
  }

  Future<void> loadVideo() async {
    final video =
        store.data['liveVideos'][store.members
                .where((m) => m.live)
                .toList()
                .indexWhere((m) => m.id == widget.member.id) %
            9];
    final path = 'assets/videos/$video';
    final controller = VideoPlayerController.networkUrl(TotiCloud.mediaUrl(path));
    p = controller;
    try {
      await controller.initialize();
      if (!mounted || p != controller) return;
      await controller.setLooping(true);
      if (routeVisible && appActive) await controller.play();
      if (mounted && p == controller) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    appActive = s == AppLifecycleState.resumed;
    if (s != AppLifecycleState.resumed) {
      p?.pause();
    } else if (routeVisible) {
      p?.play();
    }
  }

  @override
  void dispose() {
    eventTimer?.cancel();
    sampleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    p?.dispose();
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final id = 'live:${widget.member.id}';
    final messages = store
        .records('roomMessages')
        .where((message) => message['room'] == id)
        .take(2)
        .toList()
        .reversed;
    final following = store.list('following').contains(widget.member.id);
    final likes = store.get('liveHeart:${widget.member.id}', 0);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
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
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xb5000010),
                      Colors.transparent,
                      Color(0xf2000010),
                    ],
                    stops: [0, .35, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  liveControl(
                    'Back',
                    controlArtwork(0, size: 22),
                    () => Navigator.maybePop(c),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: const Color(0xff160c29).withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => open(c, MemberPage(widget.member)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                          child: Row(
                            children: [
                              avatar(widget.member.image, size: 36),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TText(
                                      widget.member.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const TText(
                                      'Recorded',
                                      style: TextStyle(
                                        color: Color(0xffffb4df),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: following
                          ? panel2.withValues(alpha: .9)
                          : pink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => setState(
                      () => store.toggle('following', widget.member.id),
                    ),
                    child: TText(following ? 'Following' : 'Follow'),
                  ),
                  const SizedBox(width: 6),
                  liveControl(
                    'Report',
                    reelArtwork(0, size: 24),
                    () => safety(c, id, widget.member),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 216,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: MediaQuery.of(c).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(.25, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: eventText == null
                      ? const SizedBox.shrink()
                      : TweenAnimationBuilder<double>(
                          key: ValueKey(eventSerial),
                          tween: Tween(begin: 0, end: 1),
                          duration: MediaQuery.of(c).disableAnimations
                              ? Duration.zero
                              : const Duration(seconds: 4),
                          builder: (context, progress, child) =>
                              Transform.translate(
                                offset: MediaQuery.of(context).disableAnimations
                                    ? Offset.zero
                                    : Offset(
                                        (.7 - progress) *
                                            MediaQuery.sizeOf(context).width *
                                            .6,
                                        0,
                                      ),
                                child: child,
                              ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 290),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xff452050,
                                ).withValues(alpha: .92),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (eventGift != null) ...[
                                    giftArtwork(eventGift!, size: 38),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: TText(
                                      eventText!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
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
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: MediaQuery.of(c).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    child: Column(
                      key: ValueKey(sampleCursor),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final index in visibleSamples)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 280),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xff160c29,
                                ).withValues(alpha: .75),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (sampleActivity[index].gift != null) ...[
                                    giftArtwork(
                                      sampleActivity[index].gift!,
                                      size: 27,
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Flexible(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${tr('Sample')}: ',
                                            style: const TextStyle(
                                              color: Color(0xffffafd9),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          TextSpan(
                                            text: tr(
                                              sampleActivity[index].text,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final msg in messages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff160c29).withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${msg['author']}: ',
                                style: const TextStyle(
                                  color: Color(0xffffafd9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: activityText(msg['text'] as String),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: field,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => sendMessage(id),
                          decoration: InputDecoration(
                            hintText: tr('Write a message'),
                            fillColor: const Color(
                              0xff160c29,
                            ).withValues(alpha: .84),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      liveControl('Gift', giftArtwork(4, size: 34), () async {
                        final name = await showGifts(c, id, showReceipt: false);
                        if (!mounted || name == null) return;
                        final giftIndex = [
                          'Rose',
                          'Kiss',
                          'Crown',
                          'Rocket',
                        ].indexOf(name);
                        showEvent(
                          'Example gift: $name',
                          gift: giftIndex < 0 ? 4 : giftIndex,
                        );
                      }),
                      const SizedBox(width: 6),
                      liveControl('Like', reelArtwork(1, size: 25), () {
                        final key = 'liveHeart:${widget.member.id}';
                        store.put(key, (store.get(key, 0) as int) + 1);
                        showEvent('Like · ${store.get(key, 0)}');
                      }),
                      const SizedBox(width: 6),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: pink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(50, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => sendMessage(id),
                        child: const TText('Send'),
                      ),
                    ],
                  ),
                  if ((likes as int) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: TText(
                        'Like · $likes',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void sendMessage(String id) {
    final text = field.text.trim();
    if (!allowed(text)) {
      notice(
        context,
        'Message not sent',
        'Please enter a clear, safe message.',
      );
      return;
    }
    final author = store.get('nickname', 'Nani Kohli') as String;
    store.addRecord('roomMessages', {
      'room': id,
      'author': author,
      'text': text,
    });
    field.clear();
    showEvent('$author: $text');
  }
}

Widget inboxShortcut({
  required String title,
  required String subtitle,
  required int artwork,
  required Color color,
  required VoidCallback onTap,
}) => TotiPressable(
  onTap: onTap,
  child: Container(
    constraints: const BoxConstraints(minHeight: 88),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        inboxArtwork(artwork, size: 40),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TText(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              TText(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xffd7c5df), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

Widget inboxEmpty(int artwork, String title, String detail) => Padding(
  padding: const EdgeInsets.fromLTRB(12, 44, 12, 24),
  child: Column(
    children: [
      inboxArtwork(artwork, size: 76),
      const SizedBox(height: 14),
      TText(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      TText(
        detail,
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 13, height: 1.4),
      ),
    ],
  ),
);

Widget inboxRows(List<Widget> rows) => Material(
  color: const Color(0xff190c31),
  borderRadius: BorderRadius.circular(18),
  clipBehavior: Clip.antiAlias,
  child: Column(
    children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0)
          const Padding(
            padding: EdgeInsets.only(left: 76, right: 14),
            child: Divider(height: 1, thickness: .5, color: Color(0xff42314e)),
          ),
        rows[i],
      ],
    ],
  ),
);

class Inbox extends StatefulWidget {
  const Inbox({super.key});
  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  String tab = 'Message';

  @override
  void initState() {
    super.initState();
    store.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_changed);
    super.dispose();
  }

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
    final messageRows = <Widget>[];
    for (final n in notices) {
      final member = store.members
          .where((m) => m.id == n['member'])
          .firstOrNull;
      if (member == null) continue;
      messageRows.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          leading: avatar(member.image, size: 48),
          title: TText(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TText(
                n['text'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xffe7cce1), fontSize: 12),
              ),
              const TText(
                'Example profile activity',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          trailing: n['read'] == true
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff5c204f),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const TText(
                    'NEW',
                    style: TextStyle(
                      color: Color(0xffffb7db),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
          onTap: () {
            final all = store.records('notices');
            for (final item in all) {
              if (item['member'] == n['member'] && item['text'] == n['text']) {
                item['read'] = true;
              }
            }
            store.put('notices', all);
            setState(() {});
            open(c, MemberPage(member));
          },
        ),
      );
    }
    for (final member in conversations) {
      final recent = store
          .records('messages')
          .firstWhere((x) => x['member'] == member.id);
      messageRows.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          leading: avatar(member.image, size: 48),
          title: TText(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TText(
                recent['text'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xffd8c9de), fontSize: 12),
              ),
              TText(
                member.authId == null ? 'Only visible to you' : 'Conversation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          onTap: () => open(c, Conversation(member)),
        ),
      );
    }
    final followingRows = [
      for (final member in following)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          leading: avatar(member.image, size: 48),
          title: TText(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: TText(
            member.authId == null ? 'Example profile · Following' : 'Following',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          trailing: actionArtwork(4, size: 18),
          onTap: () => store.mutual(member)
              ? open(c, Conversation(member))
              : open(c, MemberPage(member)),
        ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (store.social?.error != null)
          TextButton(
            onPressed: () => store.social?.retry(),
            child: TText(store.social!.error!),
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: inboxShortcut(
                  title: 'Platform updates',
                  subtitle: 'Example activity',
                  artwork: 0,
                  color: const Color(0xff2a1542),
                  onTap: () => open(c, const PlatformUpdates()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: inboxShortcut(
                  title: 'Followers',
                  subtitle: 'Example profiles',
                  artwork: 1,
                  color: const Color(0xff35173d),
                  onTap: () => open(c, const Relationships('Followers')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xff190b32),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              for (final t in ['Message', 'Follow', 'Calls', 'Moments'])
                Expanded(
                  child: Semantics(
                    selected: t == tab,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: t == tab
                            ? const Color(0xff593286)
                            : Colors.transparent,
                        foregroundColor: t == tab
                            ? Colors.white
                            : const Color(0xffc9b9d2),
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed: () => setState(() => tab = t),
                      child: TText(
                        t,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (tab == 'Message')
          messageRows.isEmpty
              ? inboxEmpty(
                  2,
                  'No messages yet',
                  'Mutual follows can start a conversation',
                )
              : inboxRows(messageRows)
        else if (tab == 'Follow')
          followingRows.isEmpty
              ? inboxEmpty(
                  1,
                  'No followed people yet',
                  'Follow someone from Discover to see them here',
                )
              : inboxRows(followingRows)
        else if (tab == 'Calls')
          inboxEmpty(3, 'No recent calls', 'Calls are not connected')
        else
          inboxRows([
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              leading: inboxArtwork(4, size: 42),
              title: const TText(
                'Moments',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const TText(
                'Browse the community feed',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              trailing: actionArtwork(4, size: 18),
              onTap: () => open(c, const Moments()),
            ),
          ]),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          const SizedBox(height: 10),
          if (notices.isEmpty)
            inboxEmpty(
              0,
              "You're all caught up",
              'Account, safety and community updates will appear here.',
            )
          else
            inboxRows([
              for (final n in notices)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: inboxArtwork(0, size: 36),
                  title: TText(
                    n['text'],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TText(
                        store.members
                                .where((m) => m.id == n['member'])
                                .map((m) => m.name)
                                .firstOrNull ??
                            '',
                      ),
                      if (n['member'] != null)
                        const TText(
                          'Example profile activity',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                    ],
                  ),
                  trailing: n['read'] == true ? null : const TText('NEW'),
                ),
            ]),
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
  bool sending = false;
  String? pendingText, pendingId;

  @override
  void initState() {
    super.initState();
    store.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_changed);
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
          if (m.authId == null)
            const Padding(
              padding: EdgeInsets.all(10),
              child: TText(
                'Messages are not sent for this profile.',
                style: TextStyle(color: muted),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                for (final msg in messages)
                  Align(
                    alignment: msg['_mine'] == false
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: msg['_mine'] == false ? panel2 : pink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TText(msg['text']),
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => openMemberCall(c, m, video: false),
                  child: iconLabel(utilityArtwork(0, size: 18), 'Voice call'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => openMemberCall(c, m, video: true),
                  child: iconLabel(utilityArtwork(1, size: 18), 'Video call'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => safety(c, 'chat:${m.id}', m),
                  child: iconLabel(utilityArtwork(2, size: 18), 'Report'),
                ),
              ],
            ),
          ),
          composer(field, () async {
            if (sending) return;
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
            if (m.authId != null) {
              final remote = store.social;
              if (remote == null) {
                notice(
                  c,
                  'Message not sent',
                  'Please check your connection and try again.',
                );
                return;
              }
              final text = field.text.trim();
              if (pendingText != text) {
                pendingText = text;
                pendingId = SocialStore.newMessageId();
              }
              setState(() => sending = true);
              try {
                await remote
                    .send(m.authId!, text, pendingId!)
                    .timeout(const Duration(seconds: 20));
                if (!mounted) return;
                if (field.text.trim() == text) field.clear();
                pendingText = null;
                pendingId = null;
              } catch (_) {
                if (mounted && c.mounted) {
                  notice(
                    c,
                    'Message not sent',
                    'Please check your connection and try again.',
                  );
                }
              } finally {
                if (mounted) setState(() => sending = false);
              }
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
                  'Calls are unavailable',
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

class RtcSessionPage extends StatefulWidget {
  const RtcSessionPage(this.session, {super.key});
  final Map<String, dynamic> session;

  @override
  State<RtcSessionPage> createState() => _RtcSessionPageState();
}

class _RtcSessionPageState extends State<RtcSessionPage>
    with WidgetsBindingObserver {
  late final String id = widget.session['id'] as String;
  late final String kind = widget.session['kind'] as String;
  late final bool owner = widget.session['owner_id'] == store.activeUserId;
  late final bool call = kind == 'voice_call' || kind == 'video_call';
  late final RtcConnection connection = RtcConnection(id);
  final field = TextEditingController();
  Timer? heartbeat;
  bool connecting = true, microphone = false, camera = false, sending = false;
  bool closed = false, hasSeenSession = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    connection.addListener(refresh);
    rtcDirectory?.addListener(sessionChanged);
    hasSeenSession = rtcDirectory?.session(id) != null;
    start();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  void sessionChanged() {
    final directory = rtcDirectory;
    if (!mounted || directory == null || directory.error != null || closed)
      return;
    final current = directory.session(id);
    if (current != null) {
      hasSeenSession = true;
      setState(() {});
    } else if (hasSeenSession && !connecting) {
      closeConnection('This session has ended.');
    }
  }

  Future<void> start() async {
    if (closed) return;
    setState(() {
      connecting = true;
      error = null;
    });
    try {
      final initialMic =
          call || (owner && (kind == 'live' || kind == 'voice_room'));
      final initialCamera = kind == 'video_call' || (owner && kind == 'live');
      await connection.connect(microphone: initialMic, camera: initialCamera);
      if (!mounted || closed) return;
      microphone = initialMic;
      camera = initialCamera;
      if (owner && !call) {
        final directory = rtcDirectory;
        if (directory == null) throw StateError('Session unavailable');
        await directory.update(id, 'publish');
      }
      if (!mounted || closed) return;
      setState(() => connecting = false);
      if (owner) {
        heartbeat = Timer.periodic(const Duration(seconds: 40), (_) async {
          try {
            await rtcDirectory?.update(id, 'heartbeat');
          } catch (_) {
            // A ringing call cannot be extended before it is accepted.
          }
        });
      }
      sessionChanged();
    } catch (_) {
      try {
        await connection.disconnect();
      } catch (_) {}
      if (mounted && !closed) {
        setState(() {
          connecting = false;
          error = 'Could not connect. Check your connection and permissions.';
        });
      }
    }
  }

  void closeConnection(String message) {
    if (closed) return;
    closed = true;
    heartbeat?.cancel();
    connection.removeListener(refresh);
    connection.dispose();
    if (mounted) setState(() => error = message);
  }

  Future<void> toggleMicrophone() async {
    if (closed || connecting) return;
    try {
      final participant = connection.room?.localParticipant;
      if (participant == null) throw StateError('Not connected');
      if (!microphone) await requireRtcPermission(camera: false);
      await participant.setMicrophoneEnabled(!microphone);
      if (mounted) setState(() => microphone = !microphone);
    } catch (_) {
      if (mounted)
        notice(
          context,
          'Microphone unavailable',
          'Check your microphone permission.',
        );
    }
  }

  Future<void> toggleCamera() async {
    if (closed || connecting) return;
    try {
      final participant = connection.room?.localParticipant;
      if (participant == null) throw StateError('Not connected');
      if (!camera) await requireRtcPermission(camera: true);
      await participant.setCameraEnabled(!camera);
      if (mounted) setState(() => camera = !camera);
    } catch (_) {
      if (mounted)
        notice(context, 'Camera unavailable', 'Check your camera permission.');
    }
  }

  Future<void> sendMessage() async {
    final text = field.text.trim();
    if (sending || !allowed(text) || text.length > 300) return;
    setState(() => sending = true);
    try {
      await connection.sendMessage(text);
      if (mounted && field.text.trim() == text) field.clear();
    } catch (_) {
      if (mounted) notice(context, 'Message not sent', 'Please try again.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String nameFor(String id) {
    if (id == store.activeUserId) return store.get('nickname', 'You') as String;
    return store.members
            .where((member) => member.authId == id)
            .firstOrNull
            ?.name ??
        'Toti member';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused || closed) return;
    final participant = connection.room?.localParticipant;
    if (participant == null) return;
    if (microphone) {
      unawaited(
        participant
            .setMicrophoneEnabled(false)
            .then<void>((_) {})
            .catchError((_) {}),
      );
    }
    if (camera) {
      unawaited(
        participant
            .setCameraEnabled(false)
            .then<void>((_) {})
            .catchError((_) {}),
      );
    }
    if (mounted)
      setState(() {
        microphone = false;
        camera = false;
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    rtcDirectory?.removeListener(sessionChanged);
    heartbeat?.cancel();
    if (!closed) {
      connection.removeListener(refresh);
      connection.dispose();
    }
    if (owner || call) {
      final directory = rtcDirectory;
      if (directory != null) {
        unawaited(directory.update(id, 'end').catchError((_) {}));
      }
    }
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final title = call
        ? nameFor(
            (owner ? widget.session['peer_id'] : widget.session['owner_id'])
                as String,
          )
        : (widget.session['title'] as String? ?? 'Toti');
    final remote = connection.remoteVideo;
    final local = connection.localVideo;
    final mainVideo = owner && kind == 'live' ? local : remote;
    final participants = [
      if (connection.room?.localParticipant != null)
        connection.room!.localParticipant!.identity,
      ...?connection.room?.remoteParticipants.values.map(
        (participant) => participant.identity,
      ),
    ];
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mainVideo != null)
              lk.VideoTrackRenderer(mainVideo, fit: lk.VideoViewFit.cover)
            else
              Image.asset(
                'assets/art/presence-constellation-field.png',
                fit: BoxFit.cover,
              ),
            Container(
              color: Colors.black.withValues(
                alpha: mainVideo == null ? .55 : .25,
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Row(
                    children: [
                      memberIconButton(
                        label: 'Back',
                        artwork: 0,
                        onTap: () => Navigator.pop(c),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TText(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (kind == 'live' && !connecting && !closed)
                        const TText(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xffff61bd),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (error != null) ...[
                          const Spacer(),
                          Center(
                            child: TText(error!, textAlign: TextAlign.center),
                          ),
                          if (!closed)
                            Center(
                              child: TextButton(
                                onPressed: start,
                                child: const TText('Try again'),
                              ),
                            ),
                          const Spacer(),
                        ] else if (connecting) ...[
                          const Spacer(),
                          const Center(
                            child: CircularProgressIndicator(color: pink),
                          ),
                          const SizedBox(height: 12),
                          const Center(child: TText('Connecting…')),
                          const Spacer(),
                        ] else ...[
                          if (call &&
                              connection.room?.remoteParticipants.isEmpty ==
                                  true)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: TText('Waiting for the other person…'),
                            ),
                          if (kind == 'voice_room') ...[
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final participant in participants)
                                  SizedBox(
                                    width: 74,
                                    child: Column(
                                      children: [
                                        if (participant == store.activeUserId)
                                          myAvatar(size: 52)
                                        else
                                          avatar(
                                            store.members
                                                    .where(
                                                      (m) =>
                                                          m.authId ==
                                                          participant,
                                                    )
                                                    .firstOrNull
                                                    ?.image ??
                                                'riverside-black-dress.jpg',
                                            size: 52,
                                          ),
                                        const SizedBox(height: 5),
                                        TText(
                                          nameFor(participant),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (call && local != null && remote != null)
                            Align(
                              alignment: Alignment.topRight,
                              child: SizedBox(
                                width: 90,
                                height: 128,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: lk.VideoTrackRenderer(
                                    local,
                                    fit: lk.VideoViewFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (!call)
                            for (final message
                                in connection.messages.reversed
                                    .take(4)
                                    .toList()
                                    .reversed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${nameFor(message.author)}: ',
                                        style: const TextStyle(
                                          color: Color(0xffff99d7),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: message.text),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (call || kind == 'voice_room' || owner)
                        VoiceRoomControl(
                          label: microphone ? 'Mute' : 'Microphone',
                          icon: roomToolbarArtwork(0),
                          onTap: toggleMicrophone,
                          active: microphone,
                        ),
                      if (kind == 'video_call' ||
                          (owner && kind == 'live')) ...[
                        const SizedBox(width: 18),
                        VoiceRoomControl(
                          label: camera ? 'Camera off' : 'Camera on',
                          icon: utilityArtwork(1),
                          onTap: toggleCamera,
                          active: camera,
                        ),
                      ],
                      const SizedBox(width: 18),
                      VoiceRoomControl(
                        label: call || owner ? 'End' : 'Leave',
                        icon: controlArtwork(0),
                        onTap: () => Navigator.pop(c),
                      ),
                    ],
                  ),
                ),
                if (!call && !closed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: composer(field, sendMessage),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
            leading: utilityArtwork(1, size: 32),
            title: const TText('Go live'),
            subtitle: const TText('Camera and microphone'),
            onTap: () {
              Navigator.pop(d);
              open(c, const LiveSetup());
            },
          ),
          ListTile(
            leading: utilityArtwork(1, size: 32),
            title: const TText('Post a video'),
            onTap: () {
              Navigator.pop(d);
              open(c, const MomentEditor(video: true));
            },
          ),
          ListTile(
            leading: cardArtwork(1),
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
          'image': 'moment-stills/garden-day-live.jpg',
          'id': 'seed-0',
          'member': 'member-0',
        },
        {
          'author': 'Amara Ndlovu',
          'text': 'What song has been on repeat for you lately?',
          'image': 'moment-stills/above-clouds-broadcast.jpg',
          'id': 'seed-1',
          'member': 'member-8',
        },
      ];
      final editorialMoments =
          ((store.data['editorialMoments'] as List?) ?? seed)
              .map((moment) => Map<String, dynamic>.from(moment as Map))
              .toList();
      final all = [...moments, ...editorialMoments]
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
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  toggleLike(c, 'moment:${e['id']}'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  actionArtwork(0, size: 18),
                                  const SizedBox(width: 6),
                                  TText(
                                    store
                                            .list('likes')
                                            .contains('moment:${e['id']}')
                                        ? 'Liked'
                                        : 'Like',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () =>
                                  showComments(c, 'moment:${e['id']}'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  actionArtwork(1, size: 18),
                                  const SizedBox(width: 6),
                                  const TText('Comment'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
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
          'Your draft is not sent for review; no review service is connected.',
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
        action('Save draft', () async {
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
            notice(c, 'Draft saved', 'Your draft is not sent for review.');
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
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/art/toti-profile-background.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xfff0b8de),
                                width: 2,
                              ),
                            ),
                            child: myAvatar(size: 70),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TText(
                                  store.get('nickname', 'Nani Kohli'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TText(
                                  '${store.get('gender', 'Female')}  ·  ${store.get('country', 'SG')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xffe6cedf),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xff2a143b,
                                    ).withValues(alpha: .85),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 40),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => open(c, const EditProfile()),
                                  child: const TText(
                                    'Edit profile',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          liveControl(
                            'Settings',
                            actionArtwork(3, size: 22),
                            () => open(c, const Settings()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xff10091f).withValues(alpha: .60),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            for (final entry in {
                              'Friends': following
                                  .where(followers.contains)
                                  .length,
                              'Following': following.length,
                              'Followers': followers.length,
                            }.entries)
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 56),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                      vertical: 6,
                                    ),
                                  ),
                                  onPressed: () =>
                                      open(c, Relationships(entry.key)),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TText(
                                        '${entry.value}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TText(
                                        entry.key,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xffe4cedf),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TotiPressable(
            onTap: () => open(c, const Vault()),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff502978), Color(0xffa02f80)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TText('MY COIN VAULT'),
                        const SizedBox(height: 4),
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
                  const SizedBox(width: 12),
                  cardArtwork(0, size: 60),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          card(
            Row(
              children: [
                cardArtwork(0, size: 36),
                const SizedBox(width: 10),
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
                  leading: cardArtwork(1),
                  title: const TText('Moments'),
                  trailing: actionArtwork(4, size: 20),
                  onTap: () => open(c, const Moments()),
                ),
                ListTile(
                  leading: cardArtwork(2),
                  title: const TText('My submissions'),
                  trailing: actionArtwork(4, size: 20),
                  onTap: () => open(c, const Pending()),
                ),
                ListTile(
                  leading: cardArtwork(3),
                  title: const TText('Effect Boutique'),
                  trailing: actionArtwork(4, size: 20),
                  onTap: () => open(c, const Boutique()),
                ),
                ListTile(
                  leading: cardArtwork(4),
                  title: const TText('Backpack'),
                  trailing: actionArtwork(4, size: 20),
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
          ? emptyState('No connections yet', artwork: 1)
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: [
                for (final m in ms)
                  listCard(
                    ListTile(
                      leading: avatar(m.image),
                      title: TText(m.name),
                      subtitle: TText(m.region),
                      trailing: actionArtwork(4, size: 18),
                      onTap: () => open(c, MemberPage(m)),
                    ),
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
  XFile? selectedAvatar;
  bool saving = false;
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

  Future<void> chooseAvatar() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (mounted && image != null) setState(() => selectedAvatar = image);
    } catch (_) {
      if (mounted) {
        notice(context, 'Could not select photo', 'Please try again.');
      }
    }
  }

  Future<void> saveProfile() async {
    if (saving) return;
    final date = DateTime.tryParse(birthday.text);
    final now = DateTime.now();
    final adult =
        date != null &&
        !date.isAfter(DateTime(now.year - 18, now.month, now.day));
    if (!allowed(name.text) || !adult || country.text.trim().isEmpty) {
      notice(
        context,
        'Check your profile',
        'Enter a nickname, country and valid adult birthday.',
      );
      return;
    }
    setState(() => saving = true);
    final account = store.activeUserId;
    String? avatarPath;
    String? uploadedAvatar;
    late Map<String, dynamic> savedProfile;
    try {
      if (selectedAvatar != null) {
        final directory = await getApplicationDocumentsDirectory();
        avatarPath =
            '${directory.path}/toti_avatar_${DateTime.now().microsecondsSinceEpoch}';
        if (await File(selectedAvatar!.path).length() > 10 * 1024 * 1024) {
          throw const FormatException('Image is too large');
        }
        await File(selectedAvatar!.path).copy(avatarPath);
        final lower = selectedAvatar!.path.toLowerCase();
        final guessedMime = lower.endsWith('.png')
            ? 'image/png'
            : lower.endsWith('.webp')
            ? 'image/webp'
            : lower.endsWith('.gif')
            ? 'image/gif'
            : lower.endsWith('.heic')
            ? 'image/heic'
            : lower.endsWith('.heif')
            ? 'image/heif'
            : lower.endsWith('.jpg') || lower.endsWith('.jpeg')
            ? 'image/jpeg'
            : 'application/octet-stream';
        final bytes = await File(selectedAvatar!.path).readAsBytes();
        final mime =
            lookupMimeType(
              selectedAvatar!.path,
              headerBytes: bytes.take(defaultMagicNumbersMaxLength).toList(),
            ) ??
            selectedAvatar!.mimeType ??
            guessedMime;
        if (bytes.length > 10 * 1024 * 1024 ||
            !{
              'image/jpeg',
              'image/png',
              'image/webp',
              'image/gif',
              'image/heic',
              'image/heif',
            }.contains(mime)) {
          throw const FormatException('Unsupported image');
        }
        uploadedAvatar = await TotiCloud.uploadAvatar(bytes, mime);
      }
      savedProfile = await TotiCloud.saveProfile({
        'nickname': name.text.trim(),
        'gender': gender,
        'birthday': birthday.text,
        'country': country.text.trim(),
        'avatar_key': uploadedAvatar ?? store.get('avatar_key', null),
      });
    } on FormatException {
      if (avatarPath != null) {
        try {
          await File(avatarPath).delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => saving = false);
        notice(
          context,
          'Could not save photo',
          'Choose an image under 10 MB and try again.',
        );
      }
      return;
    } catch (_) {
      if (avatarPath != null) {
        try {
          await File(avatarPath).delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => saving = false);
        notice(
          context,
          'Could not save profile',
          'Please check your connection and try again.',
        );
      }
      return;
    }
    if (!mounted || account == null || store.activeUserId != account) return;
    store.state.addAll(savedProfile);
    if (avatarPath != null) {
      final owned = List<String>.from(store.get('ownedAvatarPaths', []));
      final previous = store.get('avatarPath', '');
      if (previous is String &&
          previous.isNotEmpty &&
          !owned.contains(previous)) {
        owned.add(previous);
      }
      owned.add(avatarPath);
      store.state['ownedAvatarPaths'] = owned;
      store.state['avatarPath'] = avatarPath;
    }
    store.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) => Screen(
    'Edit profile',
    ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Center(
          child: TextButton(
            onPressed: saving ? null : chooseAvatar,
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xffefb4df),
                      width: 2,
                    ),
                  ),
                  child: myAvatar(size: 86, previewPath: selectedAvatar?.path),
                ),
                const SizedBox(height: 8),
                iconLabel(cardArtwork(1, size: 22), 'Change photo'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const TText(
          'Your profile and photo can be seen by other signed-in members.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: name,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Nickname'),
        ),
        DropdownButtonFormField<String>(
          initialValue: gender,
          icon: controlArtwork(4, size: 20),
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
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: saving ? null : saveProfile,
            child: TText(saving ? 'Saving…' : 'Save'),
          ),
        ),
      ],
    ),
  );
}

const coinProducts = <String, int>{
  'toti_coins_500.': 500,
  'toti_coins_1050': 1050,
  'toti_coins_1650': 1650,
  'toti_coins_2900': 2900,
  'toti_coins_6000': 6000,
  'toti_coins_12500': 12500,
  'toti_coins_33000': 33000,
  'toti_coins_72000': 72000,
  'toti_coins_115000': 115000,
};

// Reference values from LookMe; Google Play determines the actual price.
const coinReferencePrices = <String, String>{
  'toti_coins_500.': 'USD 0.99',
  'toti_coins_1050': 'USD 1.99',
  'toti_coins_1650': 'USD 2.99',
  'toti_coins_2900': 'USD 4.99',
  'toti_coins_6000': 'USD 9.99',
  'toti_coins_12500': 'USD 19.99',
  'toti_coins_33000': 'USD 49.99',
  'toti_coins_72000': 'USD 99.99',
  'toti_coins_115000': 'USD 149.99',
};

class Vault extends StatefulWidget {
  const Vault({super.key});
  @override
  State<Vault> createState() => _VaultState();
}

class _VaultState extends State<Vault> {
  String? checking;
  final Map<String, String> prices = {};

  Future<void> checkProduct(String id) async {
    if (checking != null) return;
    setState(() {
      checking = id;
      prices.remove(id);
    });
    try {
      if (!await InAppPurchase.instance.isAvailable()) {
        if (mounted) {
          notice(
            context,
            'Google Play is unavailable',
            'Please check Google Play and try again.',
          );
        }
        return;
      }
      final response = await InAppPurchase.instance.queryProductDetails({id});
      if (!mounted) return;
      final product = response.productDetails
          .where((p) => p.id == id)
          .firstOrNull;
      if (response.error != null || product == null) {
        notice(
          context,
          'Coin pack unavailable',
          'This coin pack is not available from Google Play right now.',
        );
        return;
      }
      setState(() => prices[id] = product.price);
      notice(context, 'Purchases unavailable', 'Purchases are not set up yet.');
    } catch (_) {
      if (mounted) {
        notice(context, 'Unable to check coin pack', 'Please try again.');
      }
    } finally {
      if (mounted) setState(() => checking = null);
    }
  }

  @override
  Widget build(BuildContext c) => Screen(
    'Coin Vault',
    ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xff3b1957),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              coinPackArtwork(4, size: 76),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TText(
                      'Your balance',
                      style: TextStyle(color: Color(0xffe3c9e4), fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    TText(
                      '${store.get('coins', 0)}',
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const TText(
                      'Coins',
                      style: TextStyle(color: Color(0xfff4cce5), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const TText(
          'Choose a coin pack',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        const TText(
          'Purchases are not set up yet.',
          style: TextStyle(color: Color(0xffc8b5d1), fontSize: 12),
        ),
        const SizedBox(height: 6),
        const TText(
          'Reference prices are in USD. Google Play prices may vary.',
          style: TextStyle(color: Color(0xffe1c4da), fontSize: 12),
        ),
        const SizedBox(height: 6),
        const TText(
          'Coins are used for gifts and effects. See the guide below.',
          style: TextStyle(color: Color(0xffc8b5d1), fontSize: 12),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 300
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in coinProducts.entries)
                  SizedBox(
                    width: width,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 148),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        color: const Color(0xff1b0c38),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xff47235e)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              coinPackArtwork(
                                entry.value < 1650
                                    ? 0
                                    : entry.value < 6000
                                    ? 1
                                    : entry.value < 33000
                                    ? 2
                                    : entry.value < 115000
                                    ? 3
                                    : 4,
                                size: 46,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.value}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const TText(
                                      'Coins',
                                      style: TextStyle(
                                        color: Color(0xffd7c3dc),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            prices[entry.key] ??
                                coinReferencePrices[entry.key]!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xffffd6ea),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TText(
                            prices.containsKey(entry.key)
                                ? 'Google Play price'
                                : 'Reference price',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xffcfbbd4),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xff382052),
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: checking == null
                                  ? () => checkProduct(entry.key)
                                  : null,
                              child: TText(
                                checking == entry.key
                                    ? 'Checking…'
                                    : 'Check price',
                                maxLines: 2,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const TText(
          'How coins are used',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xff190d30),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              coinUseRow(
                giftArtwork(0, size: 34),
                'Example room gifts',
                '25–520 coins each',
                'Example gifts are not delivered to another person.',
              ),
              coinUseRow(
                cardArtwork(3, size: 30),
                'Boutique items',
                '25–680 coins each',
                'Collected items are added to your Backpack.',
              ),
              coinUseRow(
                actionArtwork(1, size: 29),
                'Messages, comments and follows',
                'No coins required',
                'These actions do not use coins.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const TText(
          'Coins are virtual items and cannot be exchanged for cash.',
          style: TextStyle(color: Color(0xffb9a7c4), fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );
}

Widget coinUseRow(Widget icon, String title, String cost, String description) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 38, height: 38, child: Center(child: icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TText(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                TText(
                  cost,
                  style: const TextStyle(
                    color: Color(0xffffa7d9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                TText(
                  description,
                  style: const TextStyle(
                    color: Color(0xffc9b8d1),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

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
                    e[3] == 'Live Gift'
                        ? actionArtwork(2, size: 36)
                        : cardArtwork(3, size: 36),
                    const SizedBox(width: 12),
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
                          '${e[1]} was added to your collection.',
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
          ? emptyState('Your backpack is empty', artwork: 4)
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: [
                for (final e in items)
                  listCard(
                    ListTile(
                      leading: cardArtwork(3),
                      title: TText(e['name']),
                      subtitle: const TText('Collected effect'),
                    ),
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
          ? emptyState('No submissions yet', artwork: 2)
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: [
                for (final e in items)
                  listCard(
                    ListTile(
                      leading: cardArtwork(2),
                      title: TText(e['text']),
                      subtitle: const TText(
                        'Not sent · no review service connected',
                      ),
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
        padding: const EdgeInsets.all(16),
        children: [
          card(
            Column(
              children: [
                ListTile(
                  leading: utilityArtwork(4),
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
                  trailing: actionArtwork(4, size: 18),
                  onTap: () => open(c, const LanguagePicker()),
                ),
                ListTile(
                  leading: utilityArtwork(2),
                  title: const TText('Privacy Policy'),
                  trailing: actionArtwork(4, size: 18),
                  onTap: () =>
                      open(c, const PolicyPage('Privacy Policy', privacyUrl)),
                ),
                ListTile(
                  leading: cardArtwork(2, size: 26),
                  title: const TText('Terms of Service'),
                  trailing: actionArtwork(4, size: 18),
                  onTap: () =>
                      open(c, const PolicyPage('Terms of Service', termsUrl)),
                ),
                ListTile(
                  leading: utilityArtwork(2),
                  title: const TText('Community Guidelines'),
                  trailing: actionArtwork(4, size: 18),
                  onTap: () => open(c, const Guidelines()),
                ),
                ListTile(
                  leading: utilityArtwork(2),
                  title: const TText('Blocked accounts'),
                  trailing: actionArtwork(4, size: 18),
                  onTap: () => open(c, const Blocked()),
                ),
                ListTile(
                  leading: cardArtwork(3, size: 26),
                  title: const TText('About'),
                  subtitle: const TText('Toti · Android'),
                ),
                SwitchListTile(
                  secondary: utilityArtwork(3),
                  title: const TText('Message do not disturb'),
                  value: store.get('messageDND', false),
                  onChanged: (v) => store.put('messageDND', v),
                ),
                SwitchListTile(
                  secondary: utilityArtwork(3),
                  title: const TText('Call do not disturb'),
                  value: store.get('callDND', false),
                  onChanged: (v) => store.put('callDND', v),
                ),
                ListTile(
                  title: const TText('Sign out'),
                  trailing: actionArtwork(4, size: 18),
                  onTap: () async {
                    store.logout();
                    try {
                      await TotiCloud.signOut();
                    } catch (_) {
                      // The SDK removes the local session before contacting Auth.
                    }
                    if (c.mounted) Navigator.popUntil(c, (r) => r.isFirst);
                  },
                ),
                ListTile(
                  leading: utilityArtwork(2),
                  title: const TText(
                    'Delete account data',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () => showDialog<void>(
                    context: c,
                    builder: (d) => AlertDialog(
                      title: const TText('Delete account data?'),
                      content: const TText(
                        'This removes the profile, follows, messages and activity saved in this app.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d),
                          child: const TText('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final deletingUser = store.activeUserId;
                            if (deletingUser == null) return;
                            try {
                              for (final item in store.records('pending')) {
                                final path = item['path'];
                                if (path is String &&
                                    await File(path).exists()) {
                                  await File(path).delete();
                                }
                              }
                              final directory =
                                  await getApplicationDocumentsDirectory();
                              final prefix = '${directory.path}/toti_avatar_';
                              final avatarPaths = {
                                ...List<String>.from(
                                  store.get('ownedAvatarPaths', []),
                                ),
                                if (store.get('avatarPath', '') is String)
                                  store.get('avatarPath', '') as String,
                              };
                              for (final path in avatarPaths) {
                                if (path.startsWith(prefix) &&
                                    !path
                                        .substring(prefix.length)
                                        .contains('/') &&
                                    await File(path).exists()) {
                                  await File(path).delete();
                                }
                              }
                              await TotiCloud.deleteAccount(deletingUser);
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
                            if (store.activeUserId != deletingUser) return;
                            await store.clear();
                            if (d.mounted) Navigator.pop(d);
                            if (c.mounted) {
                              Navigator.popUntil(c, (r) => r.isFirst);
                            }
                          },
                          child: const TText('Delete'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            padding: EdgeInsets.zero,
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
            ? emptyState('Your blocked list is empty.', artwork: 2)
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                children: [
                  for (final m in blocked)
                    listCard(
                      ListTile(
                        leading: avatar(m.image),
                        title: TText(m.name),
                        trailing: TextButton(
                          onPressed: () async {
                            try {
                              await store.toggle('blocked', m.id);
                            } catch (_) {
                              if (c.mounted)
                                notice(
                                  c,
                                  'Could not unblock account',
                                  'Please try again.',
                                );
                            }
                          },
                          child: const TText('Unblock'),
                        ),
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
        'Be real and be respectful\nUse an authentic identity. Do not impersonate others or manipulate follows.\n\nConsent comes first\nMessages and calls require mutual follow. Never pressure someone to follow, reply, meet or share private information.\n\nKeep people safe\nNo bullying, threats, hate speech, sexual exploitation, graphic violence, scams, spam or promotion of dangerous activity.\n\nProtect privacy\nDo not publish another person’s private information, intimate media or location without permission.\n\nUse safety tools\nReport content that violates these rules. Block a person when you do not want to see their profile, content or conversations. Reports are submitted to Toti, and the affected content is hidden from your view.',
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
  bool starting = false;
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
          'Share a live moment with the community.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: title,
          maxLength: 48,
          decoration: const InputDecoration(labelText: 'Live title'),
        ),
        const SizedBox(height: 20),
        action('Go live', () async {
          if (starting) return;
          final t = title.text.trim();
          if (t.length < 3 || !allowed(t)) {
            notice(
              c,
              'Name your live',
              'Use a clear title between 3 and 48 characters.',
            );
            return;
          }
          final directory = rtcDirectory;
          if (directory == null) return;
          setState(() => starting = true);
          try {
            final session = await directory.startSession(
              kind: 'live',
              title: t,
            );
            if (!mounted || !c.mounted) {
              await directory.update(session['id'] as String, 'end');
              return;
            }
            await Navigator.of(c).pushReplacement(
              MaterialPageRoute(builder: (_) => RtcSessionPage(session)),
            );
          } catch (_) {
            if (mounted && c.mounted) {
              notice(
                c,
                'Unable to go live',
                'Please check your connection and try again.',
              );
            }
          } finally {
            if (mounted) setState(() => starting = false);
          }
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
    'Camera',
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
                const TText('Not broadcasting'),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        for (final entry in const {
          'en': 'English',
          'zh-Hans': '简体中文',
          'es': 'Español',
          'ja': '日本語',
          'de': 'Deutsch',
        }.entries)
          listCard(
            ListTile(
              leading: utilityArtwork(4),
              title: Text(entry.value),
              trailing: store.get('language', 'en') == entry.key
                  ? const TText('Selected')
                  : null,
              onTap: () {
                store.put('language', entry.key);
              },
            ),
          ),
      ],
    ),
  );
}
