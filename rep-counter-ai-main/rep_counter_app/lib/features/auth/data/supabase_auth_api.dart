import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The few Supabase Auth calls RepCoach uses, behind an interface so
/// `SupabaseAuthRepository` is unit-tested without a network or the SDK's
/// singletons. Failures surface as the SDK's `AuthException` types.
abstract interface class SupabaseAuthApi {
  ApiSession? get currentSession;
  Stream<ApiAuthEvent> get events;

  /// Returns the session, or a user without session when email confirmation
  /// is required.
  Future<ApiSignUpResult> signUp(String email, String password,
      {required String redirectTo});
  Future<ApiSession> signInWithPassword(String email, String password);
  Future<ApiSession> signInWithIdToken(sb.OAuthProvider provider,
      {required String idToken, String? nonce});
  Future<void> resendSignup(String email, {required String redirectTo});
  Future<void> resetPasswordForEmail(String email,
      {required String redirectTo});
  Future<ApiSession> refreshSession();
  Future<ApiUser> getUser();
  Future<void> updatePassword(String password);

  /// Calls the `delete-account` Edge Function with the user's JWT, plus a
  /// fresh Apple authorization code for Apple accounts (token revocation).
  Future<void> deleteAccount({String? appleAuthorizationCode});
  Future<void> signOut();
}

@immutable
class ApiUser {
  const ApiUser(
      {required this.id,
      required this.email,
      required this.emailConfirmed,
      required this.provider,
      this.hasIdentities = true});
  final String id;
  final String? email;
  final bool emailConfirmed;

  /// `email`, `apple` or `google` (Supabase `app_metadata.provider`).
  final String provider;

  /// False for the obfuscated user Supabase returns when signing up an
  /// address that already has an account.
  final bool hasIdentities;
}

@immutable
class ApiSession {
  const ApiSession(this.user, {this.isExpired = false});
  final ApiUser user;

  /// The access token's expiry passed; a refresh is needed.
  final bool isExpired;
}

@immutable
class ApiSignUpResult {
  const ApiSignUpResult(this.user, this.session);
  final ApiUser user;
  final ApiSession? session;
}

enum ApiAuthEventKind {
  signedIn,
  signedOutByUser,
  signedOutExpired,
  passwordRecovery,
  updated,
}

@immutable
class ApiAuthEvent {
  const ApiAuthEvent(this.kind, [this.session]);
  final ApiAuthEventKind kind;
  final ApiSession? session;
}

/// The real adapter over `Supabase.instance.client`.
class GoTrueSupabaseAuthApi implements SupabaseAuthApi {
  GoTrueSupabaseAuthApi(this._client);
  final sb.SupabaseClient _client;
  sb.GoTrueClient get _auth => _client.auth;

  static ApiUser _user(sb.User u) => ApiUser(
        id: u.id,
        email: u.email,
        emailConfirmed: u.emailConfirmedAt != null,
        provider: (u.appMetadata['provider'] as String?) ?? 'email',
        hasIdentities: u.identities == null || u.identities!.isNotEmpty,
      );

  static ApiSession _session(sb.Session s) =>
      ApiSession(_user(s.user), isExpired: s.isExpired);

  @override
  ApiSession? get currentSession {
    final s = _auth.currentSession;
    return s == null ? null : _session(s);
  }

  @override
  Stream<ApiAuthEvent> get events => _auth.onAuthStateChange
          .handleError((Object _) {}) // refresh errors also arrive as events
          .map((s) {
        final session = s.session == null ? null : _session(s.session!);
        return switch (s.event) {
          sb.AuthChangeEvent.signedIn ||
          sb.AuthChangeEvent.initialSession =>
            ApiAuthEvent(ApiAuthEventKind.signedIn, session),
          sb.AuthChangeEvent.passwordRecovery =>
            ApiAuthEvent(ApiAuthEventKind.passwordRecovery, session),
          sb.AuthChangeEvent.signedOut =>
            s.signOutReason == sb.SignOutReason.sessionExpired
                ? const ApiAuthEvent(ApiAuthEventKind.signedOutExpired)
                : const ApiAuthEvent(ApiAuthEventKind.signedOutByUser),
          _ => ApiAuthEvent(ApiAuthEventKind.updated, session),
        };
      });

  @override
  Future<ApiSignUpResult> signUp(String email, String password,
      {required String redirectTo}) async {
    final r = await _auth.signUp(
        email: email, password: password, emailRedirectTo: redirectTo);
    return ApiSignUpResult(
        _user(r.user!), r.session == null ? null : _session(r.session!));
  }

  @override
  Future<ApiSession> signInWithPassword(String email, String password) async =>
      _session(
          (await _auth.signInWithPassword(email: email, password: password))
              .session!);

  @override
  Future<ApiSession> signInWithIdToken(sb.OAuthProvider provider,
          {required String idToken, String? nonce}) async =>
      _session((await _auth.signInWithIdToken(
              provider: provider, idToken: idToken, nonce: nonce))
          .session!);

  @override
  Future<void> resendSignup(String email, {required String redirectTo}) =>
      _auth.resend(
          type: sb.OtpType.signup, email: email, emailRedirectTo: redirectTo);

  @override
  Future<void> resetPasswordForEmail(String email,
          {required String redirectTo}) =>
      _auth.resetPasswordForEmail(email, redirectTo: redirectTo);

  @override
  Future<ApiSession> refreshSession() async =>
      _session((await _auth.refreshSession()).session!);

  @override
  Future<ApiUser> getUser() async => _user((await _auth.getUser()).user!);

  @override
  Future<void> updatePassword(String password) =>
      _auth.updateUser(sb.UserAttributes(password: password));

  @override
  Future<void> deleteAccount({String? appleAuthorizationCode}) async {
    final r = await _client.functions.invoke('delete-account', body: {
      if (appleAuthorizationCode != null)
        'apple_authorization_code': appleAuthorizationCode,
    });
    if (r.status < 200 || r.status >= 300) {
      throw sb.AuthException('delete-account failed',
          statusCode: '${r.status}');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
