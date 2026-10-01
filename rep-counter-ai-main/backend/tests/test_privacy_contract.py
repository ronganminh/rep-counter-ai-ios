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
        self.assertIn("2026-10-01-groq", POLICY)
        self.assertIn("effectiveDate = '01/10/2026'", LEGAL)
        self.assertIn("effectiveDateEn = 'October 1, 2026'", LEGAL)
        self.assertIn("aiConsentVersion = '2026-10-01-groq'", LEGAL)
        self.assertIn("LegalConfig.aiConsentVersion", CONSENT)

    def test_public_url_matches_nginx_route(self):
        self.assertIn(
            "https://repcoach-ai.duckdns.org/privacy-policy.html", LEGAL
        )
        self.assertIn("location = /privacy-policy.html", NGINX)
        self.assertIn("default_type text/html;", NGINX)
        self.assertIn("charset utf-8;", NGINX)

    def test_groq_is_current_provider_policy(self):
        self.assertIn('provider_name = os.getenv("AI_PROVIDER", "groq")', PROVIDER)
        self.assertIn("class GroqProvider", PROVIDER)
        self.assertIn("GroqCloud AI service", POLICY)
        self.assertIn("Dịch vụ AI GroqCloud", POLICY)
        self.assertNotIn("Google Gemini paid service", POLICY)

    def test_policy_discloses_server_metadata_and_retention(self):
        self.assertIn("source IP address", POLICY)
        self.assertIn("random per-request request ID", POLICY)
        self.assertIn("not used as a user identifier", POLICY)
        self.assertIn("request ID ngẫu nhiên", POLICY)
        self.assertIn("14 rotated files", POLICY)
        self.assertIn("system journal", POLICY)
        self.assertIn("địa chỉ IP nguồn", POLICY)
        self.assertIn("14 file đã xoay vòng", POLICY)

    def test_policy_discloses_groq_data_treatment(self):
        self.assertIn("not retained by default", POLICY)
        self.assertIn("up to 30 days", POLICY)
        self.assertIn("does not currently claim that ZDR is enabled", POLICY)
        self.assertIn("không tuyên bố ZDR đã được bật", POLICY)
        self.assertIn("not used to train or fine-tune models", POLICY)

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

    def test_provider_end_user_terms_are_disclosed(self):
        self.assertIn("Customer Application", POLICY)
        self.assertIn("End Users", POLICY)
        self.assertIn("age of majority", POLICY)
        self.assertNotIn("Gemini-backed AI", CONSENT)

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
