import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/auth_repository.dart';
import 'native_id_tokens.dart';
import 'supabase_auth_api.dart';

/// [AuthRepository] on Supabase Auth (D-12). Email + password with
/// verification and reset links; Google through native ID tokens; Apple
/// through the native sheet on iOS and Supabase's web (OAuth) flow
/// elsewhere ([appleNative]).
/// Error messages and tokens are never logged or shown; only the mapped
/// [AuthFailureKind] reaches the UI.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required this.api,
    required this.providers,
    required this.redirectUrl,
    NativeIdTokens? nativeTokens,
    this.appleNative = true,
    Stream<void> Function()? appResumes,
    this.appleWebGrace = const Duration(seconds: 20),
    this.appleWebTimeout = const Duration(minutes: 5),
  })  : _native = nativeTokens,
        _resumes = appResumes ?? appResumeStream;

  final SupabaseAuthApi api;
  @override
  final Set<AuthProvider> providers;
  final String redirectUrl;
  final NativeIdTokens? _native;

  /// Sign in with Apple through the native sheet (iOS). False: the web
  /// flow (Android), which also cannot fetch an authorization code for
  /// token revocation at account deletion.
  final bool appleNative;

  /// Fires when the app comes back to the foreground (web flow).
  final Stream<void> Function() _resumes;

  /// Web flow: after coming back without a session, how long to wait for
  /// the deep link's code exchange before treating it as cancelled; and
  /// the overall limit.
  final Duration appleWebGrace, appleWebTimeout;

  /// Apple shares only the name and email (or a Hide My Email relay
  /// address); nothing else is asked for.
  static const appleScopes = 'name email';

  /// Last email used, for "Resend email" when there is no session yet.
  String? _pendingEmail;

  @override
  Stream<AuthEvent> get events => api.events.expand((e) => switch (e.kind) {
        ApiAuthEventKind.signedIn when e.session != null => [
            AuthEvent(AuthEventKind.signedIn, _session(e.session!))
          ],
        ApiAuthEventKind.passwordRecovery => [
            AuthEvent(AuthEventKind.passwordRecovery,
                e.session == null ? null : _session(e.session!))
          ],
        ApiAuthEventKind.signedOutExpired => [
            const AuthEvent(AuthEventKind.expired)
          ],
        _ => const <AuthEvent>[],
      });

  static AuthProvider _provider(String p) => switch (p) {
        'apple' => AuthProvider.apple,
        'google' => AuthProvider.google,
        _ => AuthProvider.email,
      };

  static AuthUser _user(ApiUser u) => AuthUser(
      id: u.id,
      email: u.email,
      emailVerified: u.emailConfirmed,
      provider: _provider(u.provider));

  static AuthSession _session(ApiSession s, {bool expired = false}) =>
      AuthSession(_user(s.user), expired: expired);

  /// Maps SDK and transport errors to what the UI distinguishes.
  static AuthFailure _failure(Object e, [AuthProvider? provider]) {
    if (e is AuthFailure) return e;
    if (e is SocketException ||
        e is TimeoutException ||
        e is HttpException ||
        e is http.ClientException ||
        e is sb.AuthRetryableFetchException ||
        // delete-account could not be reached (no response at all).
        e is sb.FunctionsFetchException) {
      return AuthFailure(AuthFailureKind.network, provider);
    }
    if (e is sb.AuthWeakPasswordException) {
      return const AuthFailure(AuthFailureKind.weakPassword);
    }
    if (e is sb.AuthSessionMissingException) {
      return const AuthFailure(AuthFailureKind.recoveryLinkInvalid);
    }
    if (e is sb.AuthException) {
      final kind = switch (e.code) {
        'invalid_credentials' => AuthFailureKind.invalidCredentials,
        'email_not_confirmed' => AuthFailureKind.emailNotConfirmed,
        'user_already_exists' ||
        'email_exists' ||
        'identity_already_exists' =>
          AuthFailureKind.accountExists,
        'weak_password' => AuthFailureKind.weakPassword,
        'over_request_rate_limit' ||
        'over_email_send_rate_limit' ||
        'too_many_requests' =>
          AuthFailureKind.tooManyAttempts,
        'session_not_found' ||
        'session_expired' ||
        'otp_expired' ||
        'flow_state_expired' ||
        'flow_state_not_found' =>
          AuthFailureKind.recoveryLinkInvalid,
        'bad_oauth_callback' ||
        'bad_jwt' when provider != null =>
          AuthFailureKind.providerFailed,
        _ => e.statusCode == '429'
            ? AuthFailureKind.tooManyAttempts
            : provider != null
                ? AuthFailureKind.providerFailed
                : AuthFailureKind.unavailable,
      };
      return AuthFailure(kind, provider);
    }
    return AuthFailure(
        provider == null
            ? AuthFailureKind.unavailable
            : AuthFailureKind.providerFailed,
        provider);
  }

  Future<T> _guard<T>(Future<T> Function() call,
      [AuthProvider? provider]) async {
    try {
      return await call();
    } catch (e) {
      throw _failure(e, provider);
    }
  }

  @override
  Future<AuthSession?> restore() async {
    final s = api.currentSession;
    if (s == null) return null;
    if (!s.isExpired) return _session(s);
    try {
      return _session(await api.refreshSession());
    } catch (e) {
      // Offline: keep the user signed in; the SDK retries the refresh.
      if (_failure(e).kind == AuthFailureKind.network) return _session(s);
      return _session(s, expired: true);
    }
  }

  @override
  Future<AuthSession> signInWithEmail(String email, String password) =>
      _guard(() async {
        try {
          return _session(await api.signInWithPassword(email, password));
        } on sb.AuthException catch (e) {
          if (e.code == 'email_not_confirmed') _pendingEmail = email;
          rethrow;
        }
      });

  @override
  Future<AuthSession> signUpWithEmail(String email, String password) =>
      _guard(() async {
        final r = await api.signUp(email, password, redirectTo: redirectUrl);
        _pendingEmail = email;
        final session = r.session;
        if (session != null) return _session(session);
        // Confirmation required. Supabase answers an already-registered
        // address the same way (a user without identities) so sign-up never
        // reveals which emails exist; both show "check your inbox".
        return AuthSession(AuthUser(
            id: r.user.hasIdentities ? r.user.id : '',
            email: email,
            emailVerified: false,
            provider: AuthProvider.email));
      });

  NativeIdTokens get _tokens =>
      _native ?? (throw const AuthFailure(AuthFailureKind.unavailable));

  @override
  Future<AuthSession> signInWithApple() => _guard(() async {
        if (!providers.contains(AuthProvider.apple)) {
          throw const AuthFailure(AuthFailureKind.unavailable);
        }
        if (!appleNative) return _session(await _appleWeb());
        final t = await _tokens.apple();
        return _session(await api.signInWithIdToken(sb.OAuthProvider.apple,
            idToken: t.idToken, nonce: t.rawNonce));
      }, AuthProvider.apple);

  /// Supabase's OAuth page in the browser; the redirect deep link signs in
  /// and arrives as an event. Coming back without one (the user closed the
  /// browser) is a cancel, after [appleWebGrace] for the code exchange.
  Future<ApiSession> _appleWeb() async {
    final done = Completer<ApiSession>();
    Timer? grace;
    void cancel() {
      if (!done.isCompleted) {
        done.completeError(
            const AuthFailure(AuthFailureKind.cancelled, AuthProvider.apple));
      }
    }

    final events = api.events.listen((e) {
      if (e.kind == ApiAuthEventKind.signedIn &&
          e.session != null &&
          !done.isCompleted) {
        done.complete(e.session!);
      }
    });
    final resumes = _resumes().listen((_) {
      grace?.cancel();
      grace = Timer(appleWebGrace, cancel);
    });
    try {
      final opened = await api.signInWithOAuth(sb.OAuthProvider.apple,
          redirectTo: redirectUrl, scopes: appleScopes);
      if (!opened) {
        throw const AuthFailure(
            AuthFailureKind.providerFailed, AuthProvider.apple);
      }
      return await done.future.timeout(appleWebTimeout, onTimeout: () {
        throw const AuthFailure(AuthFailureKind.cancelled, AuthProvider.apple);
      });
    } finally {
      grace?.cancel();
      await events.cancel();
      await resumes.cancel();
    }
  }

  @override
  Future<AuthSession> signInWithGoogle() => _guard(() async {
        if (!providers.contains(AuthProvider.google)) {
          throw const AuthFailure(AuthFailureKind.unavailable);
        }
        final t = await _tokens.google();
        return _session(await api.signInWithIdToken(sb.OAuthProvider.google,
            idToken: t.idToken));
      }, AuthProvider.google);

  @override
  Future<void> resendVerification() => _guard(() async {
        final email = api.currentSession?.user.email ?? _pendingEmail;
        if (email == null) {
          throw const AuthFailure(AuthFailureKind.unavailable);
        }
        await api.resendSignup(email, redirectTo: redirectUrl);
      });

  @override
  Future<AuthSession> reload() => _guard(() async {
        final s = api.currentSession;
        if (s == null) {
          // Not signed in yet (confirmation pending): the verify link signs
          // in through a deep link, which arrives as an event.
          final email = _pendingEmail;
          if (email == null) {
            throw const AuthFailure(AuthFailureKind.unavailable);
          }
          return AuthSession(AuthUser(
              id: '',
              email: email,
              emailVerified: false,
              provider: AuthProvider.email));
        }
        await api.refreshSession();
        return AuthSession(_user(await api.getUser()));
      });

  @override
  Future<void> requestPasswordReset(String email) =>
      _guard(() => api.resetPasswordForEmail(email, redirectTo: redirectUrl));

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => api.updatePassword(newPassword));

  @override
  Future<void> deleteAccount() => _guard(() async {
        final session = api.currentSession;
        if (session == null) {
          throw const AuthFailure(AuthFailureKind.unavailable);
        }
        // Apple accounts: a fresh authorization code lets the server revoke
        // the Sign in with Apple token (App Store 5.1.1(v)). Cancelling the
        // sheet cancels the deletion; nothing is deleted.
        String? appleCode;
        if (session.user.provider == 'apple' &&
            appleNative &&
            providers.contains(AuthProvider.apple)) {
          appleCode = await _tokens.appleAuthorizationCode();
        }
        await api.deleteAccount(appleAuthorizationCode: appleCode);
        try {
          await api.signOut();
        } catch (_) {
          // The account is gone server-side; the local session is cleared
          // by the SDK either way.
        }
      });

  @override
  Future<void> signOut() async {
    _pendingEmail = null;
    await api.signOut();
  }
}

/// App resumes, from [AppLifecycleListener] (one listener per subscriber).
Stream<void> appResumeStream() {
  AppLifecycleListener? listener;
  late final StreamController<void> c;
  c = StreamController<void>(
    onListen: () =>
        listener = AppLifecycleListener(onResume: () => c.add(null)),
    onCancel: () => listener?.dispose(),
  );
  return c.stream;
}
