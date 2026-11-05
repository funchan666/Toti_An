import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toti_an/main.dart' as app;
import 'package:toti_an/store.dart';

Finder label(String text) => find.byWidgetPredicate(
  (widget) => widget.runtimeType == Text && (widget as Text).data == text,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app.store = AppStore();
    await app.store.init();
  });

  test(
    'sample content, follow state and blocks are kept consistently',
    () async {
      expect(app.store.members.length, 47);
      expect(app.store.records('comments'), isNotEmpty);
      final member = app.store.members.first;
      app.store.toggle('following', member.id);
      app.store.put('followers', [member.id]);
      expect(app.store.mutual(member), isTrue);
      app.store.block(member);
      expect(app.store.mutual(member), isFalse);
      expect(app.store.list('following'), isNot(contains(member.id)));
      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.list('blocked'), contains(member.id));
    },
  );

  test('content screening rejects dangerous and repetitive input', () {
    expect(allowed('Hello from the city'), isTrue);
    expect(allowed('kill yourself'), isFalse);
    expect(allowed('aaaaaaaaaaaa'), isFalse);
    expect(allowed(''), isFalse);
  });

  testWidgets('agreement gates login and opens the discovery page', (
    tester,
  ) async {
    await tester.pumpWidget(const app.TotiApp());
    await tester.pumpAndSettle();
    expect(label('Toti'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'example123',
    );
    await tester.ensureVisible(label('Continue in preview'));
    await tester.tap(label('Continue in preview'));
    await tester.pumpAndSettle();
    expect(label('Agree to continue'), findsOneWidget);
    await tester.tap(label('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('accept-terms')));
    await tester.tap(find.byKey(const ValueKey('accept-terms')));
    await tester.ensureVisible(label('Continue in preview'));
    await tester.tap(label('Continue in preview'));
    await tester.pumpAndSettle();
    expect(label('Welcome to Toti'), findsOneWidget);
    expect(app.store.get('coins', 0), 888);
    await tester.tap(label('Continue').last);
    await tester.pumpAndSettle();
    expect(label('Discover'), findsWidgets);
    await tester.pump(const Duration(seconds: 25));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('main sections and daily reward work on a phone-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    app.store.login();
    await tester.pumpWidget(const app.TotiApp());
    await tester.pumpAndSettle();
    await tester.tap(label('Continue').last);
    await tester.pumpAndSettle();
    await tester.tap(label('Party').last);
    await tester.pumpAndSettle();
    expect(label('Glow After Dark'), findsOneWidget);
    await tester.tap(label('Glow After Dark'));
    await tester.pumpAndSettle();
    expect(label('Join stage'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Hello, room');
    await tester.tap(label('Send'));
    await tester.pumpAndSettle();
    expect(label('Hello, room'), findsOneWidget);
    await tester.tap(label('Gifts'));
    await tester.pumpAndSettle();
    await tester.tap(label('Rose'));
    await tester.pumpAndSettle();
    expect(app.store.get('coins', 0), 863);
    await tester.tap(label('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(label('Profile').last);
    await tester.pumpAndSettle();
    expect(label('Daily Coin Drop  +50'), findsOneWidget);
    await tester.tap(label('Collect'));
    await tester.pumpAndSettle();
    expect(app.store.get('coins', 0), 913);
    await tester.tap(label('OK'));
    await tester.pumpAndSettle();
    await tester.tap(label('Collected'));
    await tester.pumpAndSettle();
    expect(app.store.get('coins', 0), 913);
    await tester.tap(label('OK'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 25));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'a profile can be followed and messaging requires mutual follow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      app.store.login();
      await tester.pumpWidget(const app.TotiApp());
      await tester.pumpAndSettle();
      await tester.tap(label('Continue').last);
      await tester.pumpAndSettle();
      await tester.tap(label('Sofía Marin, 23'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(label('Follow').last);
      await tester.pumpAndSettle();
      await tester.tap(label('Follow').last);
      await tester.pumpAndSettle();
      expect(app.store.list('following'), contains('member-1'));
      await tester.tap(label('Message').last);
      await tester.pumpAndSettle();
      expect(label('Mutual follow required'), findsOneWidget);
      await tester.tap(label('OK'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('main tabs fit a narrow screen with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    app.store.login();
    await tester.pumpWidget(const app.TotiApp());
    await tester.pumpAndSettle();
    await tester.tap(label('Continue').last);
    await tester.pumpAndSettle();
    await tester.tap(label('Party').last);
    await tester.pumpAndSettle();
    await tester.tap(label('Message').last);
    await tester.pumpAndSettle();
    await tester.tap(label('Profile').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 25));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('language selection updates the interface and is saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    app.store.login();
    await tester.pumpWidget(const app.TotiApp());
    await tester.pumpAndSettle();
    await tester.tap(label('Continue').last);
    await tester.pumpAndSettle();
    await tester.tap(label('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(label('App language'));
    await tester.pumpAndSettle();
    await tester.tap(label('简体中文'));
    await tester.pumpAndSettle();
    expect(app.store.get('language', 'en'), 'zh-Hans');
    expect(label('发现'), findsWidgets);
    await tester.pump(const Duration(seconds: 25));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('deleting account clears local data and returns to login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    app.store.login();
    await tester.pumpWidget(const app.TotiApp());
    await tester.pumpAndSettle();
    await tester.tap(label('Continue').last);
    await tester.pumpAndSettle();
    await tester.tap(label('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(label('Delete account data'));
    await tester.pumpAndSettle();
    await tester.tap(label('Delete account data'));
    await tester.pumpAndSettle();
    await tester.tap(label('Delete'));
    await tester.pumpAndSettle();
    expect(app.store.get('signedIn', false), false);
    expect(app.store.get('coins', 0), 0);
    expect(label('Continue in preview'), findsOneWidget);
    await tester.pump(const Duration(seconds: 25));
    await tester.pumpWidget(const SizedBox());
  });
}
