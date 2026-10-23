import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart' show AppLanguage;
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';
import 'package:rep_counter_app/features/auth/domain/merge_preview.dart';
import 'package:rep_counter_app/features/auth/presentation/auth_gate_page.dart';
import 'package:rep_counter_app/features/auth/presentation/auth_welcome_page.dart';
import 'package:rep_counter_app/features/auth/presentation/merge_preview_page.dart';
import 'package:rep_counter_app/features/auth/presentation/sign_in_page.dart';
import 'package:rep_counter_app/features/home/presentation/home_screen.dart';
import 'package:rep_counter_app/features/profile/presentation/profile_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/l10n.dart';

/// A-1 Phase 9 auth screens over the [FakeAuthRepository].

const _user = AuthUser(
    id: 'u1',
    email: 'a@example.com',
    emailVerified: true,
    provider: AuthProvider.email);

Future<void> _pump(WidgetTester tester, Widget home,
    {AuthController? auth}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController(AppLanguage.en);
  addTearDown(locale.dispose);
  final app = MaterialApp(
    theme: RepCoachTheme.dark(),
    locale: AppLanguage.en.locale,
    supportedLocales: testSupportedLocales,
    localizationsDelegates: testLocalizationsDelegates,
    navigatorObservers: [appRouteObserver],
    home: home,
  );
  await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: auth == null ? app : AuthScope(controller: auth, child: app)));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

/// Restores outside the widget-test fake-async zone, where the fake's
/// timers run.
Future<void> _restore(WidgetTester tester, AuthController auth) =>
    tester.runAsync(auth.restore);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('accounts off: Profile has no sign-in entry', (tester) async {
    await _pump(tester, const ProfilePage());
    expect(find.byKey(const Key('profile-guest-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-sign-in')), findsNothing);
  });

  testWidgets('no backend configured: welcome says so, guest still works',
      (tester) async {
    final auth = AuthController(const UnconfiguredAuthRepository());
    await _pump(tester, const ProfilePage(), auth: auth);
    await _tap(tester, find.byKey(const Key('profile-sign-in')));
    expect(find.byKey(const Key('auth-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('auth-apple')), findsNothing);
    expect(find.byKey(const Key('auth-create-account')), findsNothing);
    await _tap(tester, find.byKey(const Key('auth-continue-guest')));
    expect(find.byType(AuthWelcomePage), findsNothing);
    expect(auth.state, isA<AuthGuest>());
  });

  testWidgets('welcome lists Apple before Google', (tester) async {
    final auth = AuthController(FakeAuthRepository());
    await _pump(tester, AuthWelcomePage(controller: auth), auth: auth);
    final apple = tester.getTopLeft(find.byKey(const Key('auth-apple'))).dy;
    final google = tester.getTopLeft(find.byKey(const Key('auth-google'))).dy;
    expect(apple, lessThan(google));
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('email sign-in: validation, wrong password, then success',
      (tester) async {
    final repo = FakeAuthRepository()
      ..accounts['a@example.com'] = 'right-one-1';
    final auth = AuthController(repo);
    await _pump(tester, const ProfilePage(), auth: auth);
    await _tap(tester, find.byKey(const Key('profile-sign-in')));
    await _tap(tester, find.byKey(const Key('auth-sign-in')));

    await _tap(tester, find.byKey(const Key('auth-submit')));
    expect(find.text('Enter a full email address, like name@example.com'),
        findsOneWidget);
    expect(find.text('Enter your password'), findsWidgets);
    expect(repo.calls, isEmpty);

    await _type(tester, 'auth-email', 'a@example.com');
    await _type(tester, 'auth-password', 'wrong-one-1');
    await _tap(tester, find.byKey(const Key('auth-submit')));
    expect(find.text('Email or password is incorrect'), findsOneWidget);
    expect(auth.state, isA<AuthGuest>());

    await _type(tester, 'auth-password', 'right-one-1');
    await _tap(tester, find.byKey(const Key('auth-submit')));
    // Back on Profile, signed in.
    expect(find.byType(SignInPage), findsNothing);
    expect(find.byType(AuthWelcomePage), findsNothing);
    expect(find.byKey(const Key('profile-account-card')), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('profile-sign-out')));
    expect(find.byKey(const Key('profile-guest-card')), findsOneWidget);
  });

  testWidgets('cancelled provider sign-in changes nothing', (tester) async {
    final repo = FakeAuthRepository()
      ..nextFailure = const AuthFailure(AuthFailureKind.cancelled);
    final auth = AuthController(repo);
    await _pump(tester, AuthWelcomePage(controller: auth), auth: auth);
    await _tap(tester, find.byKey(const Key('auth-apple')));
    expect(find.text('Sign-in cancelled'), findsOneWidget);
    expect(find.byType(AuthWelcomePage), findsOneWidget);
    expect(auth.state, isA<AuthGuest>());
  });

  testWidgets('sign up → verify email → confirmed → back to Profile',
      (tester) async {
    final repo = FakeAuthRepository();
    final auth = AuthController(repo);
    await _pump(tester, const ProfilePage(), auth: auth);
    await _tap(tester, find.byKey(const Key('profile-sign-in')));
    await _tap(tester, find.byKey(const Key('auth-create-account')));

    await _type(tester, 'auth-email', 'new@example.com');
    await _type(tester, 'auth-password', 'short');
    expect(find.text('Strength: Too short'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('auth-submit')));
    expect(find.text('Use at least 10 characters'), findsOneWidget);
    expect(find.text('Tick the box to accept the Terms and Privacy Policy'),
        findsOneWidget);
    expect(repo.calls, isEmpty);

    await _type(tester, 'auth-password', 'long-enough-1');
    await _tap(tester, find.byKey(const Key('auth-terms')));
    await _tap(tester, find.byKey(const Key('auth-submit')));

    expect(find.text('Confirm your email'), findsOneWidget);
    expect(find.byKey(const Key('verify-email')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('verify-resend')));
    expect(repo.resends, 1);
    expect(find.byKey(const Key('verify-resent')), findsOneWidget);

    repo.verified.add('new@example.com');
    await _tap(tester, find.byKey(const Key('verify-check')));
    expect(find.text('Email confirmed'), findsOneWidget);
    // Merge needs sync (A-2): not offered yet.
    expect(find.byKey(const Key('verify-bring-workouts')), findsNothing);
    await _tap(tester, find.byKey(const Key('verify-done')));
    expect(find.byKey(const Key('profile-account-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-verify-email')), findsNothing);
  });

  testWidgets('existing email on sign up offers "Sign in instead"',
      (tester) async {
    final repo = FakeAuthRepository()..accounts['a@example.com'] = 'x' * 10;
    final auth = AuthController(repo);
    await _pump(tester, AuthWelcomePage(controller: auth), auth: auth);
    await _tap(tester, find.byKey(const Key('auth-create-account')));
    await _type(tester, 'auth-email', 'a@example.com');
    await _type(tester, 'auth-password', 'long-enough-1');
    await _tap(tester, find.byKey(const Key('auth-terms')));
    await _tap(tester, find.byKey(const Key('auth-submit')));
    expect(find.text('You already have an account'), findsOneWidget);
    expect(find.byKey(const Key('auth-sign-in-instead')), findsOneWidget);
  });

  testWidgets('expired session: banner, email pre-filled, sign in again',
      (tester) async {
    final repo =
        FakeAuthRepository(saved: const AuthSession(_user, expired: true))
          ..accounts['a@example.com'] = 'right-one-1';
    final auth = AuthController(repo);
    await _restore(tester, auth);
    await _pump(tester, const ProfilePage(), auth: auth);
    expect(find.text('Your session expired · sign in again'), findsOneWidget);
    await _tap(tester, find.text('Sign in').first);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('auth-email')))
            .controller!
            .text,
        'a@example.com');
    await _type(tester, 'auth-password', 'right-one-1');
    await _tap(tester, find.byKey(const Key('auth-submit')));
    expect(find.byKey(const Key('profile-session-expired')), findsNothing);
    expect(find.byKey(const Key('profile-account-card')), findsOneWidget);
  });

  group('gate with return-to', () {
    Widget launcher(List<bool> results) => Builder(
        builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => results.add(await AuthGatePage.require(
                      context, AuthGateReason.friends)),
                  child: const Text('open friends'),
                ),
              ),
            ));

    testWidgets('guest → gate; "continue as guest" returns false',
        (tester) async {
      final results = <bool>[];
      final auth = AuthController(FakeAuthRepository());
      await _pump(tester, launcher(results), auth: auth);
      await _tap(tester, find.text('open friends'));
      expect(find.text('Friends need an account'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('gate-guest')));
      expect(results, [false]);
    });

    testWidgets('signing in from the gate returns true to the caller',
        (tester) async {
      final results = <bool>[];
      final repo = FakeAuthRepository()
        ..accounts['a@example.com'] = 'right-one-1';
      final auth = AuthController(repo);
      await _pump(tester, launcher(results), auth: auth);
      await _tap(tester, find.text('open friends'));
      await _tap(tester, find.byKey(const Key('gate-sign-in')));
      await _type(tester, 'auth-email', 'a@example.com');
      await _type(tester, 'auth-password', 'right-one-1');
      await _tap(tester, find.byKey(const Key('auth-submit')));
      expect(results, [true]);
      expect(find.byType(AuthGatePage), findsNothing);
      expect(find.text('open friends'), findsOneWidget);

      // Already signed in: straight through, no gate.
      await _tap(tester, find.text('open friends'));
      expect(results, [true, true]);
      expect(find.byType(AuthGatePage), findsNothing);
    });

    testWidgets('accounts off: the gate never opens', (tester) async {
      final results = <bool>[];
      await _pump(tester, launcher(results));
      await _tap(tester, find.text('open friends'));
      expect(results, [false]);
      expect(find.byType(AuthGatePage), findsNothing);
    });
  });

  testWidgets('accounts never block training: an expired session opens Home',
      (tester) async {
    final auth = AuthController(
        FakeAuthRepository(saved: const AuthSession(_user, expired: true)));
    await _restore(tester, auth);
    await _pump(tester, const AppShell(), auth: auth);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AuthWelcomePage), findsNothing);
    expect(find.byType(SignInPage), findsNothing);
    expect(find.byType(AuthGatePage), findsNothing);
  });

  group('merge preview', () {
    test('matches by client id; conflicts need a choice', () {
      final p = MergePreview.compute(
          local: const {'a', 'b', 'c', 'd'},
          remote: const {'a', 'b', 'x'},
          conflicts: const {'b'});
      expect(p.alreadyInAccount, 1);
      expect(p.toUpload, 2);
      expect(p.needsChoice, 1);
      expect(p.hasWork, isTrue);
      expect(
          MergePreview.compute(local: const {'a'}, remote: const {'a'}).hasWork,
          isFalse);
    });

    testWidgets('nothing leaves the phone until the user confirms',
        (tester) async {
      MergeChoice? choice;
      const preview =
          MergePreview(alreadyInAccount: 9, toUpload: 6, needsChoice: 1);
      await _pump(
          tester,
          Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async => choice = await Navigator.of(
                                context)
                            .push<MergeChoice>(MaterialPageRoute(
                                builder: (_) =>
                                    const MergePreviewPage(preview: preview))),
                        child: const Text('open')),
                  )));
      await _tap(tester, find.text('open'));
      expect(
          find.text(
              'Nothing leaves this phone until you confirm the merge on the next step.'),
          findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('merge-keep')));
      expect(choice, MergeChoice.keepOnPhone);
      await _tap(tester, find.text('open'));
      await _tap(tester, find.byKey(const Key('merge-confirm')));
      expect(choice, MergeChoice.merge);
    });
  });
}
