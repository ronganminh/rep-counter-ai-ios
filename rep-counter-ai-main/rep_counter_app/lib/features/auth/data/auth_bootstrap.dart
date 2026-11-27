import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/feature_flags.dart';
import '../domain/auth_repository.dart';
import 'auth_config.dart';
import 'native_id_tokens.dart';
import 'secure_session_storage.dart';
import 'supabase_auth_api.dart';
import 'supabase_auth_repository.dart';

/// Opens the Supabase client and returns its auth API. Replaced in tests.
typedef SupabaseConnector = Future<SupabaseAuthApi> Function(
    AuthConfig config, SecretStore secrets);

Future<SupabaseAuthApi> connectSupabase(
    AuthConfig config, SecretStore secrets) async {
  final supabase = await sb.Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
    authOptions: sb.FlutterAuthClientOptions(
      authFlowType: sb.AuthFlowType.pkce,
      localStorage: SecureSessionStorage(secrets),
      pkceAsyncStorage: SecurePkceStorage(secrets),
    ),
    // Never print requests, tokens or errors.
    debug: false,
  );
  return GoTrueSupabaseAuthApi(supabase.client);
}

/// The account backend for this build:
/// - accounts off (`ENABLE_ACCOUNTS`, the production default): `null`, no
///   client is created and nothing touches the network;
/// - accounts on but `SUPABASE_URL` / `SUPABASE_ANON_KEY` missing:
///   [UnconfiguredAuthRepository] ("sign-in isn't available");
/// - otherwise [SupabaseAuthRepository]. Google and Apple are offered only
///   when their client ids / `APPLE_SIGN_IN_ENABLED` are configured.
Future<AuthRepository?> createAuthRepository({
  bool enabled = FeatureFlags.enableAccounts,
  AuthConfig? config,
  SupabaseConnector connect = connectSupabase,
  SecretStore secrets = const PlatformSecretStore(),
  bool? isIos,
  NativeIdTokens? nativeTokens,
}) async {
  if (!enabled) return null;
  final c = config ?? AuthConfig.fromEnvironment();
  if (!c.isConfigured) return const UnconfiguredAuthRepository();
  final ios = isIos ?? Platform.isIOS;
  final SupabaseAuthApi api;
  try {
    api = await connect(c, secrets);
  } catch (_) {
    return const UnconfiguredAuthRepository();
  }
  // Sign in with Apple: the native sheet on iOS, Supabase's web (OAuth)
  // flow on Android (provider `apple` with a Services ID, see
  // docs/qa/APPLE_SIGNIN_SETUP.md).
  final apple = c.appleSignInEnabled;
  // App Store 4.8 (S-5, L-D42): on iOS a third-party login needs Sign in with
  // Apple next to it, so Google is hidden whenever Apple is off.
  final google = c.googleConfigured(ios: ios) && (!ios || apple);
  return SupabaseAuthRepository(
    api: api,
    redirectUrl: c.redirectUrl,
    appleNative: ios,
    providers: {
      AuthProvider.email,
      if (apple) AuthProvider.apple,
      if (google) AuthProvider.google,
    },
    nativeTokens: nativeTokens ??
        ((apple && ios) || google
            ? PlatformNativeIdTokens(
                googleWebClientId: c.googleWebClientId,
                googleIosClientId: ios ? c.googleIosClientId : null)
            : null),
  );
}
