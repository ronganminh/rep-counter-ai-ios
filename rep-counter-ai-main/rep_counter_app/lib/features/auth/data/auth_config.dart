import 'package:flutter/foundation.dart';

/// Build-time Supabase settings (D-12, docs/implementation/05_SUPABASE_SETUP.md).
/// Every value comes from `--dart-define`; nothing is hard-coded or committed.
/// The anon (publishable) key is public by design and protected by row-level
/// security; the service-role key must never be passed here.
@immutable
class AuthConfig {
  const AuthConfig({
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.redirectUrl = defaultRedirectUrl,
    this.googleWebClientId = '',
    this.googleIosClientId = '',
    this.appleSignInEnabled = false,
  });

  factory AuthConfig.fromEnvironment() => const AuthConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
        redirectUrl: String.fromEnvironment('SUPABASE_REDIRECT_URL',
            defaultValue: defaultRedirectUrl),
        googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
        googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
        appleSignInEnabled: bool.fromEnvironment('APPLE_SIGN_IN_ENABLED'),
      );

  /// Deep link the verification and reset emails return to. Registered in
  /// Info.plist / AndroidManifest and in Supabase's redirect allow-list.
  static const defaultRedirectUrl = 'com.ronganminh.repcoach://login-callback';

  final String supabaseUrl, supabaseAnonKey, redirectUrl;
  final String googleWebClientId, googleIosClientId;

  /// Needs the Sign in with Apple capability on the App ID first.
  final bool appleSignInEnabled;

  bool get isConfigured {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        supabaseAnonKey.isNotEmpty;
  }

  /// Google needs the web client id (token audience for Supabase); iOS also
  /// needs its own client id.
  bool googleConfigured({required bool ios}) =>
      googleWebClientId.isNotEmpty && (!ios || googleIosClientId.isNotEmpty);
}
