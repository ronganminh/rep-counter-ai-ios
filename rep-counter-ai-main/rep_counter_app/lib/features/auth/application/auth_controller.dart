import 'package:flutter/foundation.dart';

import '../domain/auth_repository.dart';

/// Guest → SignedIn → Expired (A-1). Being a guest is a full state, not an
/// error: training, history and counting never depend on it.
sealed class AuthState {
  const AuthState();
}

class AuthGuest extends AuthState {
  const AuthGuest();
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);
  final AuthUser user;
  bool get needsVerification =>
      user.provider == AuthProvider.email && !user.emailVerified;
}

/// The session can no longer be refreshed. The user keeps everything local
/// and is asked to sign in again; [user] pre-fills the email.
class AuthExpired extends AuthState {
  const AuthExpired(this.user);
  final AuthUser user;
}

class AuthController extends ChangeNotifier {
  AuthController(this.repository);

  final AuthRepository repository;
  AuthState _state = const AuthGuest();
  AuthState get state => _state;

  bool _busy = false;

  /// An auth call is in flight; screens disable their buttons.
  bool get busy => _busy;

  void _set(AuthState next) {
    _state = next;
    notifyListeners();
  }

  AuthState _fromSession(AuthSession s) =>
      s.expired ? AuthExpired(s.user) : AuthSignedIn(s.user);

  /// Restores the saved session. Never throws: any failure means guest.
  Future<void> restore() async {
    try {
      final s = await repository.restore();
      _set(s == null ? const AuthGuest() : _fromSession(s));
    } catch (_) {
      _set(const AuthGuest());
    }
  }

  Future<T> _run<T>(Future<T> Function() call) async {
    if (_busy) throw StateError('auth call already running');
    _busy = true;
    notifyListeners();
    try {
      return await call();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _signIn(Future<AuthSession> Function() call) =>
      _run(() async => _set(_fromSession(await call())));

  /// Throws [AuthFailure]; the state is unchanged on failure.
  Future<void> signInWithEmail(String email, String password) =>
      _signIn(() => repository.signInWithEmail(email.trim(), password));

  Future<void> signUpWithEmail(String email, String password) =>
      _signIn(() => repository.signUpWithEmail(email.trim(), password));

  Future<void> signInWithApple() => _signIn(repository.signInWithApple);

  Future<void> signInWithGoogle() => _signIn(repository.signInWithGoogle);

  Future<void> resendVerification() => _run(repository.resendVerification);

  /// Re-reads the session, e.g. after the verification link was opened.
  Future<void> reload() => _signIn(repository.reload);

  /// Called when the repository rejects the session mid-use.
  void markExpired() {
    final s = _state;
    if (s is AuthSignedIn) _set(AuthExpired(s.user));
  }

  /// Always ends as guest, even if the server call fails: local data stays.
  Future<void> signOut() async {
    try {
      await repository.signOut();
    } catch (_) {}
    _set(const AuthGuest());
  }
}
