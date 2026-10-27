import 'dart:async';

import 'package:rep_counter_app/features/auth/data/native_id_tokens.dart';
import 'package:rep_counter_app/features/auth/data/secure_session_storage.dart';
import 'package:rep_counter_app/features/auth/data/supabase_auth_api.dart';
import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Simulated Supabase Auth API, native token sheets and keychain for tests
/// of SupabaseAuthRepository (A-1c) and the staging config.

ApiUser apiUser(String email,
        {bool confirmed = true, String provider = 'email', bool ids = true}) =>
    ApiUser(
        id: 'id-$email',
        email: email,
        emailConfirmed: confirmed,
        provider: provider,
        hasIdentities: ids);

class FakeApi implements SupabaseAuthApi {
  ApiSession? session;
  final calls = <String>[];
  Object? nextError;
  Object? refreshError;
  ApiSignUpResult? signUpResult;
  ApiUser? serverUser;
  final events$ = StreamController<ApiAuthEvent>.broadcast();

  Future<T> _call<T>(String name, T Function() body) async {
    calls.add(name);
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
    return body();
  }

  @override
  ApiSession? get currentSession => session;
  @override
  Stream<ApiAuthEvent> get events => events$.stream;

  @override
  Future<ApiSignUpResult> signUp(String email, String password,
          {required String redirectTo}) =>
      _call('signUp $email $redirectTo', () {
        final r = signUpResult ??
            ApiSignUpResult(apiUser(email, confirmed: false), null);
        session = r.session;
        return r;
      });

  @override
  Future<ApiSession> signInWithPassword(String email, String password) => _call(
      'signInWithPassword $email', () => session = ApiSession(apiUser(email)));

  @override
  Future<ApiSession> signInWithIdToken(sb.OAuthProvider provider,
          {required String idToken, String? nonce}) =>
      _call(
          'signInWithIdToken ${provider.name} $idToken ${nonce ?? '-'}',
          () => session = ApiSession(
              apiUser('x@${provider.name}.example', provider: provider.name)));

  @override
  Future<void> resendSignup(String email, {required String redirectTo}) =>
      _call('resendSignup $email $redirectTo', () {});

  @override
  Future<void> resetPasswordForEmail(String email,
          {required String redirectTo}) =>
      _call('resetPasswordForEmail $email $redirectTo', () {});

  @override
  Future<ApiSession> refreshSession() => _call('refreshSession', () {
        final e = refreshError;
        if (e != null) throw e;
        return session = ApiSession(session!.user);
      });

  @override
  Future<ApiUser> getUser() =>
      _call('getUser', () => serverUser ?? session!.user);

  @override
  Future<void> updatePassword(String password) => _call('updatePassword', () {
        if (session == null) throw sb.AuthSessionMissingException();
      });

  @override
  Future<void> deleteAccount() => _call('deleteAccount', () {});

  @override
  Future<void> signOut() => _call('signOut', () => session = null);
}

class FakeTokens implements NativeIdTokens {
  AuthFailure? fail;
  int calls = 0;
  @override
  Future<NativeIdToken> apple() async {
    calls++;
    if (fail != null) throw fail!;
    return const NativeIdToken('apple-id-token', rawNonce: 'raw-nonce');
  }

  @override
  Future<NativeIdToken> google() async {
    calls++;
    if (fail != null) throw fail!;
    return const NativeIdToken('google-id-token');
  }
}

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
