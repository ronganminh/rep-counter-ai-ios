import '../config/app_config.dart';

abstract final class LegalConfig {
  static const appName = 'RepCoach AI';

  static const developerName = 'RỒNG ẨN MÌNH';
  static const contactEmail = AppConfig.supportEmail;
  static const privacyPolicyUrl = AppConfig.privacyPolicyUrl;
  static const termsUrl = AppConfig.termsUrl;
  static const supportUrl = AppConfig.supportUrl;
  static const websiteUrl = AppConfig.websiteUrl;

  static const effectiveDate = '01/10/2026';
  static const effectiveDateEn = 'October 1, 2026';
  static const aiConsentVersion = '2026-10-01-groq';
}
