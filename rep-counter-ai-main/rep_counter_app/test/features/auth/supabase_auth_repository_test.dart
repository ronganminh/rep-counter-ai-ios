import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/data/auth_bootstrap.dart';
import 'package:rep_counter_app/features/auth/data/auth_config.dart';
import 'package:rep_counter_app/features/auth/data/secure_session_storage.dart';
import 'package:rep_counter_app/features/auth/data/supabase_auth_api.dart';
import 'package:rep_counter_app/features/auth/data/supabase_auth_repository.dart';
import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../support/fake_supabase_api.dart';

/// A-1c: SupabaseAuthRepository over a simulated Supabase Auth API.

const _redirect = 'com.ronganminh.repcoach://login-callback';

Matcher _fails(AuthFailureKind kind) =>
    throwsA(isA<AuthFailure>().having((f) => f.kind, 'kind', kind));

void main() {
  late FakeApi api;
  late FakeTokens tokens;
  SupabaseAuthRepository repo(
          {Set<AuthProvider> providers = const {AuthProvider.email}}) =>
      SupabaseAuthRepository(
          api: api,
          providers: providers,
          redirectUrl: _redirect,
          nativeTokens: tokens);

  setUp(() {
    api = FakeApi();
    tokens = FakeTokens();
  });

  group('email + password', () {
    test('sign in maps the Supabase user', () async {
      final s = await repo().signInWithEmail('a@example.com', 'pw-123456789');
      expect(s.user.email, 'a@example.com');
      expect(s.user.emailVerified, isTrue);
      expect(s.user.provider, AuthProvider.email);
      expect(s.expired, isFalse);
    });

    test('Supabase errors map to the UI failure kinds', () async {
      final r = repo();
      final cases = <Object, AuthFailureKind>{
        const sb.AuthApiException('x', code: 'invalid_credentials'):
            AuthFailureKind.invalidCredentials,
        const sb.AuthApiException('x', code: 'email_not_confirmed'):
            AuthFailureKind.emailNotConfirmed,
        const sb.AuthApiException('x', code: 'over_request_rate_limit'):
            AuthFailureKind.tooManyAttempts,
        const sb.AuthApiException('x', statusCode: '429'):
            AuthFailureKind.tooManyAttempts,
        sb.AuthRetryableFetchException(message: 'offline'):
            AuthFailureKind.network,
        const SocketException('no route'): AuthFailureKind.network,
        const sb.AuthApiException('x', code: 'signup_disabled'):
            AuthFailureKind.unavailable,
        StateError('anything else'): AuthFailureKind.unavailable,
      };
      for (final entry in cases.entries) {
        api.nextError = entry.key;
        await expectLater(r.signInWithEmail('a@example.com', 'pw-123456789'),
            _fails(entry.value),
            reason: '${entry.key}');
      }
    });

    test('failures never carry server messages or tokens', () async {
      api.nextError = const sb.AuthApiException(
          'refresh_token=SECRET-TOKEN-VALUE',
          code: 'invalid_credentials');
      try {
        await repo().signInWithEmail('a@example.com', 'pw-123456789');
        fail('should throw');
      } on AuthFailure catch (f) {
        expect(f.toString(), isNot(contains('SECRET')));
      }
    });

    test('sign up with confirmation: unverified, resend uses the redirect',
        () async {
      final r = repo();
      final s = await r.signUpWithEmail('new@example.com', 'pw-123456789');
      expect(s.user.emailVerified, isFalse);
      expect(api.calls.first, 'signUp new@example.com $_redirect');
      await r.resendVerification();
      expect(api.calls.last, 'resendSignup new@example.com $_redirect');
      // Still no session: reload keeps waiting instead of failing.
      expect((await r.reload()).user.emailVerified, isFalse);
    });

    test('an already-registered address looks the same as a new one', () async {
      api.signUpResult = ApiSignUpResult(
          apiUser('taken@example.com', confirmed: false, ids: false), null);
      final s = await repo().signUpWithEmail('taken@example.com', 'pw-1234567');
      expect(s.user.emailVerified, isFalse);
      expect(s.user.email, 'taken@example.com');
    });

    test('reload with a session refreshes and reads the verified user',
        () async {
      api.session = ApiSession(apiUser('a@example.com', confirmed: false));
      api.serverUser = apiUser('a@example.com');
      final s = await repo().reload();
      expect(s.user.emailVerified, isTrue);
      expect(api.calls, ['refreshSession', 'getUser']);
    });

    test('password reset sends the redirect; unknown emails also succeed',
        () async {
      await repo().requestPasswordReset('nobody@example.com');
      expect(api.calls.single,
          'resetPasswordForEmail nobody@example.com $_redirect');
    });

    test('updating the password without a recovery session = link invalid',
        () async {
      await expectLater(repo().updatePassword('new-password-1'),
          _fails(AuthFailureKind.recoveryLinkInvalid));
      api.session = ApiSession(apiUser('a@example.com'));
      await repo().updatePassword('new-password-1');
      expect(api.calls.last, 'updatePassword');
    });
  });

  group('session restore', () {
    test('no session → guest; valid → signed in', () async {
      expect(await repo().restore(), isNull);
      api.session = ApiSession(apiUser('a@example.com'));
      expect((await repo().restore())!.expired, isFalse);
      expect(api.calls, isEmpty, reason: 'valid session needs no refresh');
    });

    test('expired access token is refreshed', () async {
      api.session = ApiSession(apiUser('a@example.com'), isExpired: true);
      final s = await repo().restore();
      expect(s!.expired, isFalse);
      expect(api.calls, ['refreshSession']);
    });

    test('rejected refresh → expired; offline → stays signed in', () async {
      api.session = ApiSession(apiUser('a@example.com'), isExpired: true);
      api.refreshError =
          const sb.AuthApiException('x', code: 'refresh_token_not_found');
      expect((await repo().restore())!.expired, isTrue);

      api.refreshError = sb.AuthRetryableFetchException(message: 'offline');
      expect((await repo().restore())!.expired, isFalse);
    });
  });

  group('events drive the state machine', () {
    test('session expiry and password recovery reach the controller', () async {
      api.session = ApiSession(apiUser('a@example.com'));
      final c = AuthController(repo());
      addTearDown(c.dispose);
      await c.restore();
      expect(c.state, isA<AuthSignedIn>());

      api.events$.add(const ApiAuthEvent(ApiAuthEventKind.signedOutByUser));
      await pumpEventQueue();
      expect(c.state, isA<AuthSignedIn>(), reason: 'user sign-out is ours');

      api.events$.add(const ApiAuthEvent(ApiAuthEventKind.signedOutExpired));
      await pumpEventQueue();
      expect(c.state, isA<AuthExpired>());

      api.events$.add(ApiAuthEvent(ApiAuthEventKind.passwordRecovery,
          ApiSession(apiUser('a@example.com'))));
      await pumpEventQueue();
      expect(c.recoveryPending, isTrue);
      expect(c.state, isA<AuthSignedIn>());
    });

    test('a verify link that signs in updates the state', () async {
      final c = AuthController(repo());
      addTearDown(c.dispose);
      api.events$.add(ApiAuthEvent(
          ApiAuthEventKind.signedIn, ApiSession(apiUser('new@example.com'))));
      await pumpEventQueue();
      expect((c.state as AuthSignedIn).user.emailVerified, isTrue);
    });
  });

  group('Apple and Google', () {
    test('not configured: no native sheet, unavailable', () async {
      await expectLater(
          repo().signInWithApple(), _fails(AuthFailureKind.unavailable));
      await expectLater(
          repo().signInWithGoogle(), _fails(AuthFailureKind.unavailable));
      expect(tokens.calls, 0);
      expect(api.calls, isEmpty);
    });

    test('ID tokens are exchanged with Supabase; Apple sends its nonce',
        () async {
      final r = repo(providers: {
        AuthProvider.email,
        AuthProvider.apple,
        AuthProvider.google
      });
      final apple = await r.signInWithApple();
      expect(apple.user.provider, AuthProvider.apple);
      expect(
          api.calls.last, 'signInWithIdToken apple apple-id-token raw-nonce');
      final google = await r.signInWithGoogle();
      expect(google.user.provider, AuthProvider.google);
      expect(api.calls.last, 'signInWithIdToken google google-id-token -');
    });

    test('cancel in the native sheet changes nothing', () async {
      tokens.fail =
          const AuthFailure(AuthFailureKind.cancelled, AuthProvider.apple);
      await expectLater(repo(providers: {AuthProvider.apple}).signInWithApple(),
          _fails(AuthFailureKind.cancelled));
      expect(api.calls, isEmpty);
    });

    test('a Supabase rejection of the token is a provider failure', () async {
      api.nextError = const sb.AuthApiException('x', code: 'bad_jwt');
      await expectLater(
          repo(providers: {AuthProvider.google}).signInWithGoogle(),
          throwsA(isA<AuthFailure>()
              .having((f) => f.kind, 'kind', AuthFailureKind.providerFailed)
              .having((f) => f.provider, 'provider', AuthProvider.google)));
    });
  });

  group('account deletion', () {
    test('calls the server function, then ends the session', () async {
      api.session = ApiSession(apiUser('a@example.com'));
      final c = AuthController(repo());
      addTearDown(c.dispose);
      await c.restore();
      await c.deleteAccount();
      expect(api.calls, ['deleteAccount', 'signOut']);
      expect(c.state, isA<AuthGuest>());
    });

    test('server refusal keeps the user signed in', () async {
      api.session = ApiSession(apiUser('a@example.com'));
      final c = AuthController(repo());
      addTearDown(c.dispose);
      await c.restore();
      api.nextError = const sb.AuthException('500', statusCode: '500');
      await expectLater(c.deleteAccount(), throwsA(isA<AuthFailure>()));
      expect(c.state, isA<AuthSignedIn>());
      expect(api.calls, ['deleteAccount']);
    });

    test('without a session there is nothing to delete', () async {
      await expectLater(
          repo().deleteAccount(), _fails(AuthFailureKind.unavailable));
      expect(api.calls, isEmpty);
    });
  });

  group('bootstrap', () {
    const configured = AuthConfig(
        supabaseUrl: 'https://project.supabase.co',
        supabaseAnonKey: 'anon-key');
    var connects = 0;
    Future<SupabaseAuthApi> connect(AuthConfig c, SecretStore s) async {
      connects++;
      return FakeApi();
    }

    setUp(() => connects = 0);

    test('accounts off: no repository and no network client', () async {
      expect(
          await createAuthRepository(
              enabled: false, config: configured, connect: connect),
          isNull);
      expect(connects, 0);
    });

    test('missing or invalid config falls back to Unconfigured', () async {
      for (final c in const [
        AuthConfig(),
        AuthConfig(supabaseUrl: 'https://project.supabase.co'),
        AuthConfig(supabaseAnonKey: 'anon-key'),
        AuthConfig(
            supabaseUrl: 'http://project.supabase.co',
            supabaseAnonKey: 'anon-key'),
      ]) {
        expect(
            await createAuthRepository(
                enabled: true, config: c, connect: connect),
            isA<UnconfiguredAuthRepository>());
      }
      expect(connects, 0);
    });

    test('a failing client start also falls back', () async {
      expect(
          await createAuthRepository(
              enabled: true,
              config: configured,
              connect: (_, __) async => throw StateError('init failed')),
          isA<UnconfiguredAuthRepository>());
    });

    test('configured: email only until provider ids exist', () async {
      final r = await createAuthRepository(
          enabled: true, config: configured, connect: connect, isIos: true);
      expect(r, isA<SupabaseAuthRepository>());
      expect(r!.providers, {AuthProvider.email});
      expect(connects, 1);
    });

    test('Google needs the web id (and the iOS id on iOS); Apple iOS only',
        () async {
      const all = AuthConfig(
          supabaseUrl: 'https://project.supabase.co',
          supabaseAnonKey: 'anon-key',
          googleWebClientId: 'web.apps.googleusercontent.com',
          appleSignInEnabled: true);
      final ios = await createAuthRepository(
          enabled: true,
          config: all,
          connect: connect,
          isIos: true,
          nativeTokens: FakeTokens());
      expect(ios!.providers, {AuthProvider.email, AuthProvider.apple});
      final android = await createAuthRepository(
          enabled: true,
          config: all,
          connect: connect,
          isIos: false,
          nativeTokens: FakeTokens());
      expect(android!.providers, {AuthProvider.email, AuthProvider.google});
    });

    test('the redirect defaults to the app callback scheme', () {
      expect(const AuthConfig().redirectUrl, _redirect);
      expect(AuthConfig.fromEnvironment().isConfigured, isFalse,
          reason: 'no Supabase values are compiled into test builds');
    });
  });

  group('secure session storage', () {
    test('session and PKCE verifier live in the secret store', () async {
      final secrets = MemorySecrets();
      final session = SecureSessionStorage(secrets);
      expect(await session.hasAccessToken(), isFalse);
      await session.persistSession('{"access_token":"t"}');
      expect(await session.accessToken(), '{"access_token":"t"}');
      await session.removePersistedSession();
      expect(await session.hasAccessToken(), isFalse);

      final pkce = SecurePkceStorage(secrets);
      await pkce.setItem(key: 'verifier', value: 'v');
      expect(secrets.values.keys.single, '${SecurePkceStorage.prefix}verifier');
      expect(await pkce.getItem(key: 'verifier'), 'v');
      await pkce.removeItem(key: 'verifier');
      expect(secrets.values, isEmpty);
    });
  });
}
