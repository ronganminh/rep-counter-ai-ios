import 'dart:async';

import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';

/// In-memory [AuthRepository] for tests (A-1). Accounts live in [accounts];
/// set [nextFailure] to make the next call fail once.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(
      {this.providers = const {
        AuthProvider.email,
        AuthProvider.apple,
        AuthProvider.google
      },
      this.saved});

  @override
  final Set<AuthProvider> providers;

  /// Session returned by [restore].
  AuthSession? saved;
  final accounts = <String, String>{};
  final verified = <String>{};
  AuthFailure? nextFailure;
  AuthSession? _current;
  int resends = 0, signOuts = 0;
  final calls = <String>[];

  Future<T> _call<T>(String name, T Function() body) async {
    calls.add(name);
    await Future<void>.delayed(Duration.zero);
    final f = nextFailure;
    if (f != null) {
      nextFailure = null;
      throw f;
    }
    return body();
  }

  AuthSession _session(String email, AuthProvider provider) =>
      _current = AuthSession(AuthUser(
          id: 'u-$email',
          email: email,
          emailVerified:
              provider != AuthProvider.email || verified.contains(email),
          provider: provider));

  @override
  Future<AuthSession?> restore() => _call('restore', () => _current = saved);

  @override
  Future<AuthSession> signInWithEmail(String email, String password) =>
      _call('signInWithEmail', () {
        if (accounts[email] != password) {
          throw const AuthFailure(AuthFailureKind.invalidCredentials);
        }
        return _session(email, AuthProvider.email);
      });

  @override
  Future<AuthSession> signUpWithEmail(String email, String password) =>
      _call('signUpWithEmail', () {
        if (accounts.containsKey(email)) {
          throw const AuthFailure(AuthFailureKind.accountExists);
        }
        accounts[email] = password;
        return _session(email, AuthProvider.email);
      });

  @override
  Future<AuthSession> signInWithApple() => _call('signInWithApple',
      () => _session('apple@privaterelay.example', AuthProvider.apple));

  @override
  Future<AuthSession> signInWithGoogle() => _call(
      'signInWithGoogle', () => _session('g@example.com', AuthProvider.google));

  @override
  Future<void> resendVerification() =>
      _call('resendVerification', () => resends++);

  @override
  Future<AuthSession> reload() => _call('reload', () {
        final user = _current!.user;
        return _session(user.email!, user.provider);
      });

  final resetRequests = <String>[];
  String? newPassword;
  int deletions = 0;

  /// Push events as a deep link or token refresh would.
  final eventController = StreamController<AuthEvent>.broadcast();
  @override
  Stream<AuthEvent> get events => eventController.stream;

  @override
  Future<void> requestPasswordReset(String email) =>
      _call('requestPasswordReset', () => resetRequests.add(email));

  @override
  Future<void> updatePassword(String password) =>
      _call('updatePassword', () {
        newPassword = password;
        final email = _current?.user.email;
        if (email != null) accounts[email] = password;
      });

  @override
  Future<void> deleteAccount() => _call('deleteAccount', () {
        deletions++;
        final email = _current?.user.email;
        if (email != null) accounts.remove(email);
        _current = null;
      });

  @override
  Future<void> signOut() => _call('signOut', () {
        signOuts++;
        _current = null;
      });
}
