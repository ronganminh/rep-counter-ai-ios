/// Build-time configuration (roadmap F-2).
///
/// Every value can be set with `--dart-define`. Defaults are only values the
/// app already ships today (support email, legal pages served by the
/// production backend), which the owner still has to confirm as canonical
/// (PRODUCT_DECISIONS D-14). Store values have no default: an empty product
/// ID means billing is not configured. Never put invented values here.
library;

abstract final class AppConfig {
  static const supportEmail = String.fromEnvironment(
    'REPCOACH_SUPPORT_EMAIL',
    defaultValue: 'ronganminh221@gmail.com',
  );

  static const privacyPolicyUrl = String.fromEnvironment(
    'REPCOACH_PRIVACY_URL',
    defaultValue: 'https://repcoach-ai.duckdns.org/privacy-policy.html',
  );

  static const termsUrl = String.fromEnvironment(
    'REPCOACH_TERMS_URL',
    defaultValue: 'https://repcoach-ai.duckdns.org/terms.html',
  );

  static const supportUrl = String.fromEnvironment(
    'REPCOACH_SUPPORT_URL',
    defaultValue: 'https://repcoach-ai.duckdns.org/support.html',
  );

  /// `[PRODUCT_ID_PRO_MONTHLY]` / `[PRODUCT_ID_PRO_ANNUAL]` — unresolved.
  static const productIdProMonthly =
      String.fromEnvironment('REPCOACH_PRODUCT_ID_PRO_MONTHLY');
  static const productIdProAnnual =
      String.fromEnvironment('REPCOACH_PRODUCT_ID_PRO_ANNUAL');

  /// Billing UI must stay hidden until both store products are configured.
  static bool get billingConfigured =>
      productIdProMonthly.isNotEmpty && productIdProAnnual.isNotEmpty;
}
