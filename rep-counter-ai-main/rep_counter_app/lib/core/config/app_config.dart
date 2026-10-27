/// Build-time configuration (roadmap F-2).
///
/// Every value can be set with `--dart-define`. The support and legal
/// defaults are the owner's D-14 decision (2026-10-27): the values declared
/// in App Store Connect and Google Play for v1. Store values have no default:
/// prices, product IDs and trials are still undecided, so an empty product
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

  static const websiteUrl = String.fromEnvironment(
    'REPCOACH_WEBSITE_URL',
    defaultValue: 'https://repcoach-ai.duckdns.org/',
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
