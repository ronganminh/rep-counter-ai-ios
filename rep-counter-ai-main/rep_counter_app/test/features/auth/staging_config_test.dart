import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart' show AppLanguage;
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/auth/data/auth_bootstrap.dart';
import 'package:rep_counter_app/features/auth/data/auth_config.dart';
import 'package:rep_counter_app/features/auth/data/secure_session_storage.dart';
import 'package:rep_counter_app/features/auth/data/supabase_auth_api.dart';
import 'package:rep_counter_app/features/auth/data/supabase_auth_repository.dart';
import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';
import 'package:rep_counter_app/features/auth/presentation/auth_welcome_page.dart';
import 'package:rep_counter_app/features/home/presentation/home_screen.dart';
import 'package:rep_counter_app/features/profile/presentation/profile_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../support/fake_supabase_api.dart';
import '../../support/l10n.dart';

/// 05_SUPABASE_SETUP §11, the part that needs no device: the staging values
/// the owner configured, run through the real SupabaseAuthRepository over a
/// simulated Supabase API (no network).

Map<String, String> _example() =>
    (jsonDecode(File('dart_defines.staging.example.json').readAsStringSync())
            as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));

AuthConfig _staging() {
  final d = _example();
  return AuthConfig(
    supabaseUrl: d['SUPABASE_URL']!,
    // The real publishable key is never committed; any non-empty value
    // passes the config check.
    supabaseAnonKey: 'test-publishable-key',
    redirectUrl: d['SUPABASE_REDIRECT_URL']!,
    googleWebClientId: d['GOOGLE_WEB_CLIENT_ID']!,
    googleIosClientId: d['GOOGLE_IOS_CLIENT_ID']!,
    appleSignInEnabled: d['APPLE_SIGN_IN_ENABLED'] == 'true',
  );
}

Future<SupabaseAuthRepository> _repo(FakeApi api, {required bool ios}) async =>
    (await createAuthRepository(
      enabled: true,
      config: _staging(),
      connect: (_, __) async => api,
      isIos: ios,
      nativeTokens: FakeTokens(),
    ))! as SupabaseAuthRepository;

void main() {
  group('staging config file', () {
    test('the example lists only known defines and no real key', () {
      final d = _example();
      expect(d.keys.toSet(), {
        'ENABLE_ACCOUNTS',
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'SUPABASE_REDIRECT_URL',
        'GOOGLE_WEB_CLIENT_ID',
        'GOOGLE_IOS_CLIENT_ID',
        'APPLE_SIGN_IN_ENABLED',
      });
      final key = d['SUPABASE_ANON_KEY']!;
      expect(key, startsWith('<'), reason: 'placeholder only');
      expect(key, isNot(startsWith('sb_')));
      expect(key, isNot(startsWith('eyJ')));
      for (final v in d.values) {
        expect(v, isNot(contains('sb_secret_')));
        expect(v, isNot(contains('service_role')));
      }
    });

    test('the real staging file is git-ignored, the example is not', () {
      final ignore = File('.gitignore').readAsStringSync();
      expect(ignore, contains('dart_defines*.json'));
      expect(ignore, contains('!dart_defines*.example.json'));
    });

    test('redirect URL is the allow-listed scheme registered natively', () {
      final d = _example();
      expect(d['SUPABASE_REDIRECT_URL'], AuthConfig.defaultRedirectUrl);
      final scheme = Uri.parse(AuthConfig.defaultRedirectUrl).scheme;
      expect(File('ios/Runner/Info.plist').readAsStringSync(),
          contains('<string>$scheme</string>'));
      expect(
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
          contains('android:scheme="$scheme"'));
    });

    test('Info.plist carries the reversed Google iOS client id', () {
      final iosId = _example()['GOOGLE_IOS_CLIENT_ID']!;
      final reversed =
          'com.googleusercontent.apps.${iosId.replaceAll('.apps.googleusercontent.com', '')}';
      expect(File('ios/Runner/Info.plist').readAsStringSync(),
          contains('<string>$reversed</string>'));
    });

    test('Sign in with Apple entitlement is present', () {
      expect(File('ios/Runner/Runner.entitlements').readAsStringSync(),
          contains('com.apple.developer.applesignin'));
    });

    test('values are well formed', () {
      final c = _staging();
      expect(c.isConfigured, isTrue);
      expect(Uri.parse(c.supabaseUrl).host, endsWith('.supabase.co'));
      for (final id in [c.googleWebClientId, c.googleIosClientId]) {
        expect(id,
            matches(RegExp(r'^\d+-[a-z0-9]+\.apps\.googleusercontent\.com$')));
      }
    });
  });

  group('providers with staging values', () {
    test('iOS offers email, Apple and Google', () async {
      final r = await _repo(FakeApi(), ios: true);
      expect(r.providers,
          {AuthProvider.email, AuthProvider.apple, AuthProvider.google});
      expect(r.redirectUrl, AuthConfig.defaultRedirectUrl);
    });

    test('Android offers email and Google (no native Apple sheet)', () async {
      final r = await _repo(FakeApi(), ios: false);
      expect(r.providers, {AuthProvider.email, AuthProvider.google});
    });

    test('accounts off: nothing is created even with staging values', () async {
      var connects = 0;
      expect(
          await createAuthRepository(
              enabled: false,
              config: _staging(),
              connect: (_, __) async {
                connects++;
                return FakeApi();
              }),
          isNull);
      expect(connects, 0);
    });

    test('the session is written to the secret store, not preferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = MemorySecrets();
      await SecureSessionStorage(secrets)
          .persistSession('{"access_token":"t"}');
      expect(secrets.values.keys, [SecureSessionStorage.key]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.contains('supabase')), isEmpty);
    });
  });

  group('§11 flows through SupabaseAuthRepository (simulated)', () {
    test('sign up → link opened → confirmed', () async {
      final api = FakeApi();
      final c = AuthController(await _repo(api, ios: true));
      addTearDown(c.dispose);
      await c.signUpWithEmail('new@example.com', 'long-enough-1');
      expect((c.state as AuthSignedIn).needsVerification, isTrue);
      expect(api.calls.single,
          'signUp new@example.com ${AuthConfig.defaultRedirectUrl}');
      api.events$.add(ApiAuthEvent(
          ApiAuthEventKind.signedIn, ApiSession(apiUser('new@example.com'))));
      await pumpEventQueue();
      expect((c.state as AuthSignedIn).needsVerification, isFalse);
    });

    test('wrong password, then correct', () async {
      final api = FakeApi()
        ..nextError =
            const sb.AuthApiException('x', code: 'invalid_credentials');
      final c = AuthController(await _repo(api, ios: false));
      addTearDown(c.dispose);
      await expectLater(
          c.signInWithEmail('a@example.com', 'wrong-pass-1'),
          throwsA(isA<AuthFailure>().having(
              (f) => f.kind, 'kind', AuthFailureKind.invalidCredentials)));
      await c.signInWithEmail('a@example.com', 'right-pass-1');
      expect(c.state, isA<AuthSignedIn>());
    });

    test('reset link → new password', () async {
      final api = FakeApi();
      final c = AuthController(await _repo(api, ios: true));
      addTearDown(c.dispose);
      await c.requestPasswordReset('a@example.com');
      expect(api.calls.last,
          'resetPasswordForEmail a@example.com ${AuthConfig.defaultRedirectUrl}');
      api.session = ApiSession(apiUser('a@example.com'));
      api.events$
          .add(ApiAuthEvent(ApiAuthEventKind.passwordRecovery, api.session));
      await pumpEventQueue();
      expect(c.recoveryPending, isTrue);
      await c.updatePassword('new-password-1');
      expect(c.recoveryPending, isFalse);
    });

    test('Google and Apple: tokens exchanged; cancel changes nothing',
        () async {
      final api = FakeApi();
      final tokens = FakeTokens();
      final r = (await createAuthRepository(
          enabled: true,
          config: _staging(),
          connect: (_, __) async => api,
          isIos: true,
          nativeTokens: tokens))!;
      final c = AuthController(r);
      addTearDown(c.dispose);
      await c.signInWithGoogle();
      expect(api.calls.last, startsWith('signInWithIdToken google'));
      await c.signOut();
      tokens.fail =
          const AuthFailure(AuthFailureKind.cancelled, AuthProvider.apple);
      await expectLater(c.signInWithApple(), throwsA(isA<AuthFailure>()));
      expect(c.state, isA<AuthGuest>());
      tokens.fail = null;
      await c.signInWithApple();
      expect(
          api.calls.last, 'signInWithIdToken apple apple-id-token raw-nonce');
    });

    test('expired session → expired banner state; delete → guest', () async {
      final api = FakeApi()..session = ApiSession(apiUser('a@example.com'));
      final c = AuthController(await _repo(api, ios: true));
      addTearDown(c.dispose);
      await c.restore();
      api.events$.add(const ApiAuthEvent(ApiAuthEventKind.signedOutExpired));
      await pumpEventQueue();
      expect(c.state, isA<AuthExpired>());
      await c.signInWithEmail('a@example.com', 'right-pass-1');
      await c.deleteAccount();
      expect(api.calls.sublist(api.calls.length - 2),
          ['deleteAccount', 'signOut']);
      expect(c.state, isA<AuthGuest>());
    });
  });

  group('screens with staging providers', () {
    Future<void> pump(
        WidgetTester tester, Widget home, AuthController c) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(AppLanguage.en);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: AuthScope(
          controller: c,
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

    testWidgets('welcome shows Apple, Google and email sign-in on iOS',
        (tester) async {
      final r = (await tester.runAsync(() => _repo(FakeApi(), ios: true)))!;
      final c = AuthController(r);
      addTearDown(c.dispose);
      await pump(tester, AuthWelcomePage(controller: c), c);
      expect(find.byKey(const Key('auth-apple')), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      expect(find.byKey(const Key('auth-create-account')), findsOneWidget);
      expect(find.byKey(const Key('auth-unavailable')), findsNothing);
    });

    testWidgets('Profile offers sign-in; training still opens as guest',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final r = (await tester.runAsync(() => _repo(FakeApi(), ios: false)))!;
      final c = AuthController(r);
      addTearDown(c.dispose);
      await pump(tester, const ProfilePage(), c);
      expect(find.byKey(const Key('profile-sign-in')), findsOneWidget);
      await pump(tester, const AppShell(), c);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
