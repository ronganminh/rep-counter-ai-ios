import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/config/feature_flags.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';
import 'package:rep_counter_app/features/auth/domain/auth_validation.dart';

import '../../support/fake_auth_repository.dart';

/// A-1: Guest / SignedIn / Expired state machine over [AuthRepository].
void main() {
  const user = AuthUser(
      id: 'u1',
      email: 'a@example.com',
      emailVerified: true,
      provider: AuthProvider.email);

  test('accounts are off by default (production)', () {
    expect(FeatureFlags.enableAccounts, isFalse);
  });

  test('the unconfigured repository offers nothing and stays guest', () async {
    final c = AuthController(const UnconfiguredAuthRepository());
    await c.restore();
    expect(c.state, isA<AuthGuest>());
    expect(c.repository.providers, isEmpty);
    await expectLater(
        c.signInWithEmail('a@example.com', 'x' * 12),
        throwsA(isA<AuthFailure>()
            .having((f) => f.kind, 'kind', AuthFailureKind.unavailable)));
    expect(c.state, isA<AuthGuest>());
    expect(c.busy, isFalse);
  });

  test('restore: none → guest, saved → signed in, expired → expired', () async {
    final repo = FakeAuthRepository();
    final c = AuthController(repo);
    await c.restore();
    expect(c.state, isA<AuthGuest>());

    repo.saved = const AuthSession(user);
    await c.restore();
    expect((c.state as AuthSignedIn).user.id, 'u1');

    repo.saved = const AuthSession(user, expired: true);
    await c.restore();
    expect((c.state as AuthExpired).user.email, 'a@example.com');
  });

  test('a failing restore means guest, never a crash', () async {
    final repo = FakeAuthRepository()
      ..nextFailure = const AuthFailure(AuthFailureKind.network);
    final c = AuthController(repo);
    await c.restore();
    expect(c.state, isA<AuthGuest>());
  });

  test('sign up → unverified → reload after the link → verified', () async {
    final repo = FakeAuthRepository();
    final c = AuthController(repo);
    await c.signUpWithEmail(' new@example.com ', 'longenough1');
    final s = c.state as AuthSignedIn;
    expect(s.user.email, 'new@example.com');
    expect(s.needsVerification, isTrue);
    await c.resendVerification();
    expect(repo.resends, 1);
    repo.verified.add('new@example.com');
    await c.reload();
    expect((c.state as AuthSignedIn).needsVerification, isFalse);
  });

  test('wrong password keeps guest and reports invalid credentials', () async {
    final repo = FakeAuthRepository()
      ..accounts['a@example.com'] = 'right-one-1';
    final c = AuthController(repo);
    await expectLater(
        c.signInWithEmail('a@example.com', 'wrong-one-1'),
        throwsA(isA<AuthFailure>().having(
            (f) => f.kind, 'kind', AuthFailureKind.invalidCredentials)));
    expect(c.state, isA<AuthGuest>());
    await c.signInWithEmail('a@example.com', 'right-one-1');
    expect(c.state, isA<AuthSignedIn>());
  });

  test('provider sign-in needs no verification; cancel changes nothing',
      () async {
    final repo = FakeAuthRepository()
      ..nextFailure = const AuthFailure(AuthFailureKind.cancelled);
    final c = AuthController(repo);
    await expectLater(c.signInWithApple(), throwsA(isA<AuthFailure>()));
    expect(c.state, isA<AuthGuest>());
    await c.signInWithGoogle();
    expect((c.state as AuthSignedIn).needsVerification, isFalse);
  });

  test('signed in → expired → sign in again; sign out always ends guest',
      () async {
    final repo = FakeAuthRepository()
      ..accounts['a@example.com'] = 'right-one-1';
    final c = AuthController(repo);
    c.markExpired();
    expect(c.state, isA<AuthGuest>(), reason: 'guests cannot expire');
    await c.signInWithEmail('a@example.com', 'right-one-1');
    c.markExpired();
    expect(c.state, isA<AuthExpired>());
    await c.signInWithEmail('a@example.com', 'right-one-1');
    expect(c.state, isA<AuthSignedIn>());

    repo.nextFailure = const AuthFailure(AuthFailureKind.network);
    await c.signOut();
    expect(c.state, isA<AuthGuest>());
  });

  test('one call at a time; busy is reported', () async {
    final c = AuthController(FakeAuthRepository());
    final busy = <bool>[];
    c.addListener(() => busy.add(c.busy));
    final first = c.signInWithGoogle();
    expect(c.busy, isTrue);
    expect(() => c.signInWithApple(), throwsStateError);
    await first;
    expect(c.busy, isFalse);
    // started, signed in (still busy), finished.
    expect(busy, [true, true, false]);
  });

  test('validation matches the sign-up copy', () {
    expect(AuthValidation.isEmail('name@example.com'), isTrue);
    expect(AuthValidation.isEmail(' name@example.com '), isTrue);
    expect(AuthValidation.isEmail('name@example'), isFalse);
    expect(AuthValidation.isEmail('name example.com'), isFalse);
    expect(AuthValidation.isPasswordLongEnough('123456789'), isFalse);
    expect(AuthValidation.isPasswordLongEnough('1234567890'), isTrue);
  });
}
