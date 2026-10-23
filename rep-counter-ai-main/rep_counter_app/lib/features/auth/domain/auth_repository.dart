import 'package:flutter/foundation.dart';

/// Account client contract (roadmap A-1, decision D-12: Supabase Auth with
/// Apple, Google and email + password). The implementation is
/// `SupabaseAuthRepository` when Supabase is configured
/// (docs/implementation/05_SUPABASE_SETUP.md), otherwise
/// [UnconfiguredAuthRepository]; the account UI stays behind
/// `FeatureFlags.enableAccounts` (off by default).
///
/// Implementations own the session (secure storage, token refresh). They
/// report a session they can no longer refresh as [AuthSession.expired].
abstract interface class AuthRepository {
  /// Which providers this build can offer. Buttons for the others are hidden.
  Set<AuthProvider> get providers;

  /// The session restored at launch, if any.
  Future<AuthSession?> restore();

  Future<AuthSession> signInWithEmail(String email, String password);

  /// Creates the account and sends the verification email. The returned
  /// session has `user.emailVerified == false` until [reload] sees the link
  /// was opened.
  Future<AuthSession> signUpWithEmail(String email, String password);

  Future<AuthSession> signInWithApple();

  Future<AuthSession> signInWithGoogle();

  Future<void> resendVerification();

  /// Fresh state of the current session (e.g. after the verify link).
  Future<AuthSession> reload();

  /// Sends a reset link. Succeeds whether or not the address has an account,
  /// so the response never reveals which emails are registered.
  Future<void> requestPasswordReset(String email);

  /// Sets a new password for the signed-in or recovering user.
  Future<void> updatePassword(String newPassword);

  /// Asks the server to delete the account and its server data, then ends
  /// the session. Workouts stored on this phone are not touched.
  Future<void> deleteAccount();

  Future<void> signOut();

  /// Session changes the app did not ask for: a deep link completed sign-in
  /// or a password reset, or the session expired.
  Stream<AuthEvent> get events;
}

enum AuthEventKind { signedIn, expired, passwordRecovery }

@immutable
class AuthEvent {
  const AuthEvent(this.kind, [this.session]);
  final AuthEventKind kind;
  final AuthSession? session;
}

enum AuthProvider { email, apple, google }

@immutable
class AuthUser {
  const AuthUser(
      {required this.id,
      required this.email,
      required this.emailVerified,
      required this.provider});

  final String id;

  /// Null when the provider hides it (Apple private relay may still give a
  /// relay address).
  final String? email;
  final bool emailVerified;
  final AuthProvider provider;
}

@immutable
class AuthSession {
  const AuthSession(this.user, {this.expired = false});
  final AuthUser user;

  /// The refresh token was rejected: the user must sign in again. Local
  /// workouts are unaffected.
  final bool expired;
}

/// Failures the UI distinguishes (FA-auth error states).
enum AuthFailureKind {
  invalidCredentials,
  network,
  tooManyAttempts,
  unavailable,
  cancelled,
  providerFailed,

  /// The email already signs in another way (password vs provider).
  accountExists,
  weakPassword,

  /// Signed up but the verification link was not opened yet.
  emailNotConfirmed,

  /// The reset link expired or was already used.
  recoveryLinkInvalid,
}

class AuthFailure implements Exception {
  const AuthFailure(this.kind, [this.provider]);
  final AuthFailureKind kind;
  final AuthProvider? provider;
  @override
  String toString() =>
      'AuthFailure($kind${provider == null ? '' : ', $provider'})';
}

/// The production default until D-12's backend is chosen and configured:
/// no providers, no session, every call fails as unavailable. No endpoint,
/// client id or entitlement is assumed.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  static Never _fail() => throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Set<AuthProvider> get providers => const {};
  @override
  Future<AuthSession?> restore() async => null;
  @override
  Future<AuthSession> signInWithEmail(String email, String password) async =>
      _fail();
  @override
  Future<AuthSession> signUpWithEmail(String email, String password) async =>
      _fail();
  @override
  Future<AuthSession> signInWithApple() async => _fail();
  @override
  Future<AuthSession> signInWithGoogle() async => _fail();
  @override
  Future<void> resendVerification() async => _fail();
  @override
  Future<AuthSession> reload() async => _fail();
  @override
  Future<void> requestPasswordReset(String email) async => _fail();
  @override
  Future<void> updatePassword(String newPassword) async => _fail();
  @override
  Future<void> deleteAccount() async => _fail();
  @override
  Future<void> signOut() async {}
  @override
  Stream<AuthEvent> get events => const Stream.empty();
}
