import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/auth_repository.dart';

/// ID token from the native Apple / Google sheet, exchanged with Supabase
/// via `signInWithIdToken` (the flow Supabase recommends for Flutter).
class NativeIdToken {
  const NativeIdToken(this.idToken, {this.rawNonce});
  final String idToken;

  /// Apple only: the unhashed nonce; Apple saw its SHA-256.
  final String? rawNonce;
}

abstract interface class NativeIdTokens {
  /// Throws [AuthFailure] (cancelled / providerFailed).
  Future<NativeIdToken> apple();
  Future<NativeIdToken> google();
}

class PlatformNativeIdTokens implements NativeIdTokens {
  PlatformNativeIdTokens(
      {required this.googleWebClientId, this.googleIosClientId});

  final String googleWebClientId;
  final String? googleIosClientId;
  bool _googleReady = false;

  static String _nonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  @override
  Future<NativeIdToken> apple() async {
    final rawNonce = _nonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final token = credential.identityToken;
      if (token == null) {
        throw const AuthFailure(
            AuthFailureKind.providerFailed, AuthProvider.apple);
      }
      return NativeIdToken(token, rawNonce: rawNonce);
    } on SignInWithAppleAuthorizationException catch (e) {
      throw AuthFailure(
          e.code == AuthorizationErrorCode.canceled
              ? AuthFailureKind.cancelled
              : AuthFailureKind.providerFailed,
          AuthProvider.apple);
    } on SignInWithAppleException {
      throw const AuthFailure(
          AuthFailureKind.providerFailed, AuthProvider.apple);
    }
  }

  @override
  Future<NativeIdToken> google() async {
    final google = GoogleSignIn.instance;
    try {
      if (!_googleReady) {
        await google.initialize(
            clientId: googleIosClientId, serverClientId: googleWebClientId);
        _googleReady = true;
      }
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const AuthFailure(
            AuthFailureKind.providerFailed, AuthProvider.google);
      }
      return NativeIdToken(token);
    } on GoogleSignInException catch (e) {
      throw AuthFailure(
          e.code == GoogleSignInExceptionCode.canceled
              ? AuthFailureKind.cancelled
              : AuthFailureKind.providerFailed,
          AuthProvider.google);
    }
  }
}
