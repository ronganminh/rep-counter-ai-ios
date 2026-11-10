// QA v2 · J-06 account UI through the real shell with an in-memory auth
// backend (no network, no keys): guest → Profile › Sign in; provider order
// (App Store 4.8: Apple no smaller / not below Google); signed in →
// Profile › Delete account (5.1.1(v), Play account deletion): typed
// confirmation, network failure leaves the user signed in, success screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';
import 'package:rep_counter_app/features/auth/presentation/auth_welcome_page.dart';
import 'package:rep_counter_app/features/auth/presentation/password_reset_pages.dart';
import 'package:rep_counter_app/features/auth/presentation/sign_in_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:rep_counter_app/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/fake_auth_repository.dart';
import '../test/support/l10n.dart';
import 'support/app_harness.dart';

void main() {
  final binding = ensureQaBinding();
  late PluginFakes fakes;

  setUp(() {
    fakes = PluginFakes(binding.defaultBinaryMessenger)..install();
  });
  tearDown(() => fakes.uninstall());

  const user = AuthUser(
      id: 'u-1',
      email: 'qa@example.com',
      emailVerified: true,
      provider: AuthProvider.email);

  Future<AuthController> pumpShell(WidgetTester tester,
      {AuthSession? saved, AppLanguage language = AppLanguage.en}) async {
    SharedPreferences.setMockInitialValues({'onboarding_v1': true});
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeAuthRepository(saved: saved);
    final auth = AuthController(repo);
    addTearDown(auth.dispose);
    // The fake backend completes on a real microtask: run it outside the
    // test's fake clock.
    await tester.runAsync(auth.restore);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        locale: language.locale,
        supportedLocales: testSupportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
        navigatorObservers: [appRouteObserver],
        home: AuthScope(controller: auth, child: const AppShell()),
      ),
    ));
    await settle(tester);
    return auth;
  }

  Finder tab(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  testWidgets(
      'guest: Profile offers Sign in; welcome → sign in shows Apple above '
      'Google, equal size, then email', (tester) async {
    await pumpShell(tester);
    await tester.tap(tab('Profile'));
    await settle(tester);
    expect(find.byKey(const Key('profile-guest-card')), findsOneWidget);
    await tapKey(tester, 'profile-sign-in');
    expect(find.byType(AuthWelcomePage), findsOneWidget);
    expect(find.byKey(const Key('auth-continue-guest')), findsOneWidget,
        reason: '5.1.1(v): the app can be used without a login');
    await tapKey(tester, 'auth-sign-in');
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing, reason: 'D-02');

    final apple = find.byKey(const Key('auth-apple'));
    final google = find.byKey(const Key('auth-google'));
    expect(apple, findsOneWidget);
    expect(google, findsOneWidget);
    expect(tester.getTopLeft(apple).dy, lessThan(tester.getTopLeft(google).dy),
        reason: 'Apple first');
    expect(tester.getSize(apple).height,
        greaterThanOrEqualTo(tester.getSize(google).height),
        reason: '4.8 / HIG: Sign in with Apple no smaller than other buttons');
    expect(tester.getSize(apple).width,
        greaterThanOrEqualTo(tester.getSize(google).width));
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-forgot-password')), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets(
      'signed in: Delete account needs the typed word; a network failure '
      'keeps the user signed in; success shows the confirmation',
      (tester) async {
    final auth = await pumpShell(tester, saved: const AuthSession(user));
    expect(auth.state, isA<AuthSignedIn>());
    await tester.tap(tab('Profile'));
    await settle(tester);
    expect(find.byKey(const Key('profile-account-card')), findsOneWidget);
    expect(find.text('qa@example.com'), findsOneWidget);

    await tapKey(tester, 'profile-delete-account');
    expect(find.byType(DeleteAccountPage), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing, reason: 'D-02');
    expect(find.byKey(const Key('delete-help')), findsOneWidget,
        reason: 'support contact on the deletion page');
    final button = find.byKey(const Key('delete-confirm'));
    expect(tester.widget<AppButton>(button).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(tester.widget<AppButton>(button).onPressed, isNotNull,
        reason: 'DELETE / XÓA, case-insensitive (L-D09)');

    final repo = auth.repository as FakeAuthRepository;
    repo.nextFailure = const AuthFailure(AuthFailureKind.network);
    await tester.tap(button);
    await settle(tester);
    expect(find.byKey(const Key('delete-failed')), findsOneWidget);
    expect(auth.state, isA<AuthSignedIn>(), reason: 'nothing deleted');
    expect(repo.deletions, 0);

    await tester.tap(button);
    await settle(tester);
    expect(find.byKey(const Key('delete-done')), findsOneWidget);
    expect(repo.deletions, 1);
    expect(auth.state, isNot(isA<AuthSignedIn>()));
    await tapKey(tester, 'delete-done');
    expect(find.byType(DeleteAccountPage), findsNothing);
    expect(find.byKey(const Key('profile-guest-card')), findsOneWidget,
        reason: 'back to the guest profile; training continues');
    await closeApp(tester);
  });

  testWidgets('Vietnamese: XÓA is accepted on the delete-account page',
      (tester) async {
    await pumpShell(tester,
        saved: const AuthSession(user), language: AppLanguage.vi);
    await tester.tap(tab('Hồ sơ'));
    await settle(tester);
    await tapKey(tester, 'profile-delete-account');
    final button = find.byKey(const Key('delete-confirm'));
    await tester.enterText(find.byType(TextField), 'xóa');
    await tester.pump();
    expect(tester.widget<AppButton>(button).onPressed, isNotNull);
    await closeApp(tester);
  });
}
