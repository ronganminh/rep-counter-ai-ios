import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart' show AppLanguage;
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';
import 'package:rep_counter_app/features/auth/presentation/password_reset_pages.dart';
import 'package:rep_counter_app/features/auth/presentation/sign_in_page.dart';
import 'package:rep_counter_app/features/profile/presentation/profile_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/l10n.dart';

/// A-1c: password reset, reset-link recovery and account deletion screens.

const _user = AuthUser(
    id: 'u1',
    email: 'a@example.com',
    emailVerified: true,
    provider: AuthProvider.email);

Future<void> _pump(WidgetTester tester, Widget home,
    {required AuthController auth}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController(AppLanguage.en);
  addTearDown(locale.dispose);
  await tester.pumpWidget(LocaleScope(
    controller: locale,
    child: AuthScope(
      controller: auth,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        locale: AppLanguage.en.locale,
        supportedLocales: testSupportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
        navigatorObservers: [appRouteObserver],
        home: home,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<AuthController> _signedIn(WidgetTester tester) async {
  final repo = FakeAuthRepository(saved: const AuthSession(_user))
    ..accounts['a@example.com'] = 'old-password-1';
  final auth = AuthController(repo);
  addTearDown(auth.dispose);
  await tester.runAsync(auth.restore);
  return auth;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('forgot password: validates, sends, shows the address',
      (tester) async {
    final repo = FakeAuthRepository();
    final auth = AuthController(repo);
    addTearDown(auth.dispose);
    await _pump(tester, SignInPage(controller: auth), auth: auth);
    await tester.enterText(find.byKey(const Key('auth-email')), 'a@example');
    await _tap(tester, find.byKey(const Key('auth-forgot-password')));
    expect(find.text('Reset your password'), findsOneWidget);
    // The sign-in email is carried over and checked.
    await _tap(tester, find.byKey(const Key('reset-send')));
    expect(find.text('Enter a full email address, like name@example.com'),
        findsOneWidget);
    expect(repo.resetRequests, isEmpty);

    await tester.enterText(
        find.byKey(const Key('auth-email')), 'a@example.com');
    await _tap(tester, find.byKey(const Key('reset-send')));
    expect(repo.resetRequests, ['a@example.com']);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.byKey(const Key('reset-sent-to')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('reset-resend')));
    expect(repo.resetRequests, hasLength(2));
    await _tap(tester, find.byKey(const Key('reset-back')));
    expect(find.byType(SignInPage), findsOneWidget);
  });

  testWidgets('a reset link opens "choose a new password" and saves it',
      (tester) async {
    final auth = await _signedIn(tester);
    final repo = auth.repository as FakeAuthRepository;
    await _pump(tester, const AuthRecoveryListener(child: ProfilePage()),
        auth: auth);
    expect(find.byType(ChooseNewPasswordPage), findsNothing);

    repo.eventController.add(
        const AuthEvent(AuthEventKind.passwordRecovery, AuthSession(_user)));
    await tester.pumpAndSettle();
    expect(find.text('Choose a new password'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth-password')), 'short');
    await _tap(tester, find.byKey(const Key('reset-save')));
    expect(repo.newPassword, isNull);
    await tester.enterText(
        find.byKey(const Key('auth-password')), 'new-password-1');
    await _tap(tester, find.byKey(const Key('reset-save')));
    expect(repo.newPassword, 'new-password-1');
    expect(find.text('Password updated'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('reset-done')));
    expect(find.byType(ChooseNewPasswordPage), findsNothing);
    expect(auth.recoveryPending, isFalse);
  });

  testWidgets('an expired reset link offers a new one', (tester) async {
    final auth = await _signedIn(tester);
    final repo = auth.repository as FakeAuthRepository;
    await _pump(tester, ChooseNewPasswordPage(controller: auth), auth: auth);
    repo.nextFailure = const AuthFailure(AuthFailureKind.recoveryLinkInvalid);
    await tester.enterText(
        find.byKey(const Key('auth-password')), 'new-password-1');
    await _tap(tester, find.byKey(const Key('reset-save')));
    expect(find.text('This reset link no longer works'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('reset-request-new')));
    expect(find.text('Reset your password'), findsOneWidget);
  });

  testWidgets('delete account needs the typed word; then guest',
      (tester) async {
    final auth = await _signedIn(tester);
    final repo = auth.repository as FakeAuthRepository;
    await _pump(tester, const ProfilePage(), auth: auth);
    await _tap(tester, find.byKey(const Key('profile-delete-account')));
    expect(find.text('This deletes your account'), findsOneWidget);

    Future<void> tryDelete() =>
        _tap(tester, find.byKey(const Key('delete-confirm')));
    await tryDelete();
    expect(repo.deletions, 0, reason: 'disabled until confirmed');

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    repo.nextFailure = const AuthFailure(AuthFailureKind.network);
    await tryDelete();
    expect(find.byKey(const Key('delete-failed')), findsOneWidget);
    expect(auth.state, isA<AuthSignedIn>());

    await tryDelete();
    expect(repo.deletions, 1);
    expect(find.text('Your account is being deleted'), findsOneWidget);
    expect(auth.state, isA<AuthGuest>());
    await _tap(tester, find.byKey(const Key('delete-done')));
    expect(find.byKey(const Key('profile-guest-card')), findsOneWidget);
  });
}
