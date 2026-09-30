import unittest
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
PROJECT = BACKEND.parent
POLICY = (BACKEND / "static" / "privacy-policy.html").read_text(encoding="utf-8")
NGINX = (BACKEND / "deploy" / "repcoach-ai.nginx").read_text(encoding="utf-8")
PROVIDER = (BACKEND / "ai_provider.py").read_text(encoding="utf-8")
LEGAL = (
    PROJECT
    / "rep_counter_app"
    / "lib"
    / "core"
    / "legal"
    / "legal_config.dart"
).read_text(encoding="utf-8-sig")
CONSENT = (
    PROJECT
    / "rep_counter_app"
    / "lib"
    / "features"
    / "ai"
    / "presentation"
    / "ai_consent.dart"
).read_text(encoding="utf-8")
PREFS = (
    PROJECT
    / "rep_counter_app"
    / "lib"
    / "features"
    / "ai"
    / "ai_preferences.dart"
).read_text(encoding="utf-8")
STRINGS = (
    PROJECT
    / "rep_counter_app"
    / "lib"
    / "core"
    / "i18n"
    / "app_strings.dart"
).read_text(encoding="utf-8")


class PrivacyContractTests(unittest.TestCase):
    def test_policy_is_bilingual_and_mobile_readable(self):
        self.assertIn('name="viewport"', POLICY)
        self.assertIn('id="en"', POLICY)
        self.assertIn('id="vi"', POLICY)
        self.assertIn('lang="en"', POLICY)
        self.assertIn('lang="vi"', POLICY)

    def test_policy_and_app_share_effective_date_and_consent_version(self):
        self.assertIn("October 1, 2026", POLICY)
        self.assertIn("2026-10-01", POLICY)
        self.assertIn("effectiveDate = '01/10/2026'", LEGAL)
        self.assertIn("effectiveDateEn = 'October 1, 2026'", LEGAL)
        self.assertIn("aiConsentVersion = '2026-10-01'", LEGAL)
        self.assertIn("LegalConfig.aiConsentVersion", CONSENT)

    def test_public_url_matches_nginx_route(self):
        self.assertIn(
            "https://repcoach-ai.duckdns.org/privacy-policy.html", LEGAL
        )
        self.assertIn("location = /privacy-policy.html", NGINX)
        self.assertIn("default_type text/html;", NGINX)
        self.assertIn("charset utf-8;", NGINX)

    def test_paid_mode_is_single_provider_policy(self):
        self.assertIn('SUPPORTED_GEMINI_SERVICE_MODES = {"billing_enabled"}', PROVIDER)
        self.assertIn("billing-enabled Gemini API project", POLICY)
        self.assertIn("Gemini API project đã xác minh có billing", POLICY)
        self.assertNotIn('SUPPORTED_GEMINI_SERVICE_MODES = {"unpaid"', PROVIDER)

    def test_policy_discloses_server_metadata_and_retention(self):
        self.assertIn("source IP address", POLICY)
        self.assertIn("14 rotated files", POLICY)
        self.assertIn("system journal", POLICY)
        self.assertIn("địa chỉ IP nguồn", POLICY)
        self.assertIn("14 file đã xoay vòng", POLICY)

    def test_policy_discloses_paid_provider_data_treatment(self):
        self.assertIn("does not use paid-service prompts or responses", POLICY)
        self.assertIn("limited period", POLICY)
        self.assertIn("does not claim a specific Google retention period", POLICY)
        self.assertIn("không tuyên bố có trạng thái zero-data-retention", POLICY)

    def test_policy_and_consent_cover_ai_optionality(self):
        for value in (
            "Automatic AI feedback is off by default",
            "older history is not automatically uploaded",
            "cannot recall a request already sent",
            "Manual AI feedback requires a per-request confirmation",
        ):
            self.assertIn(value, POLICY)
        self.assertIn("Older history is not uploaded automatically", CONSENT)
        self.assertIn("This consent applies only to the request", CONSENT)

    def test_age_requirement_is_consistent(self):
        self.assertIn("aged 18 or older", POLICY)
        self.assertIn("18 tuổi trở lên", POLICY)
        self.assertIn("aged 18 or older", CONSENT)
        self.assertIn("18 tuổi trở lên", CONSENT)

    def test_automatic_consent_key_is_versioned(self):
        self.assertIn("automatic_ai_consent_2026_10_01", PREFS)
        self.assertNotIn("automatic_ai_consent_v1", PREFS)

    def test_no_stale_android_only_instructions(self):
        combined = "\n".join((POLICY, STRINGS, CONSENT))
        self.assertNotIn("Android settings", combined)
        self.assertNotIn("cài đặt Android", combined)

    def test_policy_excludes_workout_media_from_ai_payload(self):
        self.assertIn("camera images", POLICY)
        self.assertIn("raw pose-landmark coordinates", POLICY)
        self.assertIn("ảnh camera", POLICY)
        self.assertIn("tọa độ landmark thô", POLICY)

    def test_policy_has_no_external_scripts(self):
        self.assertNotIn("<script", POLICY.lower())
        self.assertNotIn("google-analytics", POLICY.lower())


if __name__ == "__main__":
    unittest.main()
