import re
import unittest
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
PROJECT = BACKEND.parent
RUNBOOK = (BACKEND / "docs" / "production-release.md").read_text(encoding="utf-8")
README = (BACKEND / "README.md").read_text(encoding="utf-8")
GUIDE = (PROJECT / "docs" / "DEPLOY_GUIDE.md").read_text(encoding="utf-8")
SMOKE = (BACKEND / "tools" / "production_smoke.py").read_text(encoding="utf-8")
NGINX = (BACKEND / "deploy" / "repcoach-ai.nginx").read_text(encoding="utf-8")
RATE = (BACKEND / "deploy" / "repcoach-rate-limit.conf").read_text(encoding="utf-8")
ROTATE = (BACKEND / "deploy" / "repcoach-ai.logrotate").read_text(encoding="utf-8")
SERVICE = (BACKEND / "deploy" / "repcoach-backend.service").read_text(encoding="utf-8")


class ProductionReleaseTests(unittest.TestCase):
    def test_runbook_documents_required_process_management(self):
        for value in (
            "repcoach-backend",
            "/home/nduythanh/apps/repcoach-backend",
            "/home/nduythanh/apps/repcoach-backend/.env",
            "sudo systemctl restart repcoach-backend",
            "sudo journalctl -u repcoach-backend",
            "/var/log/nginx/repcoach-ai.access.log",
            "## Rollback",
        ):
            self.assertIn(value, RUNBOOK)

    def test_runbook_does_not_claim_billing_is_verified(self):
        self.assertIn("BLOCKED / admin action required", RUNBOOK)
        self.assertIn("must still be verified", README)
        self.assertIn("Google AI Studio", RUNBOOK)
        self.assertNotIn("billing verification: PASS", RUNBOOK)

    def test_runbook_keeps_secrets_out_of_repo(self):
        self.assertIn("GEMINI_API_KEY=<server secret>", RUNBOOK)
        self.assertNotRegex(RUNBOOK, r"GEMINI_API_KEY=[A-Za-z0-9_-]{20,}")
        self.assertNotIn("BEGIN OPENSSH PRIVATE KEY", RUNBOOK)

    def test_legacy_deploy_guide_points_to_canonical_policy(self):
        self.assertIn("../backend/static/privacy-policy.html", GUIDE)
        self.assertIn("../backend/docs/production-release.md", GUIDE)
        self.assertNotIn("/var/www/repcoach-ai", GUIDE)
        self.assertIn(
            "https://repcoach-ai.duckdns.org/privacy-policy.html",
            GUIDE,
        )

    def test_public_smoke_uses_shared_v2_fixture(self):
        self.assertIn("workout_feedback_v2.json", SMOKE)
        self.assertIn('fixture.get("schema_version") == 2', SMOKE)
        self.assertIn('fixture.get("consent_version") == "2026-10-01"', SMOKE)
        self.assertIn("PRODUCTION_SMOKE_PASS", SMOKE)

    def test_public_smoke_checks_required_routes_and_safety(self):
        for value in (
            '"/health"',
            '"/ready"',
            '"/privacy-policy.html"',
            '"/v1/workout-feedback"',
            "strict-transport-security",
            "x-content-type-options",
            "X-Request-ID",
            "GEMINI_API_KEY",
        ):
            self.assertIn(value, SMOKE)

    def test_deploy_files_cover_b7_runtime_controls(self):
        for value in (
            'Strict-Transport-Security "max-age=31536000"',
            "client_max_body_size 16k;",
            "limit_req zone=repcoach_api",
            "proxy_read_timeout 22s;",
            "location = /privacy-policy.html",
            "location = /health",
            "location = /ready",
        ):
            self.assertIn(value, NGINX)
        self.assertIn("rate=10r/m", RATE)
        self.assertIn("rotate 14", ROTATE)
        self.assertIn("WorkingDirectory=/home/nduythanh/apps/repcoach-backend", SERVICE)
        self.assertIn(
            "EnvironmentFile=/home/nduythanh/apps/repcoach-backend/.env",
            SERVICE,
        )

    def test_rollback_backup_names_do_not_collide(self):
        for value in (
            "$backup/system/nginx-site",
            "$backup/system/rate-limit.conf",
            "$backup/system/logrotate",
        ):
            self.assertIn(value, RUNBOOK)
        self.assertEqual(RUNBOOK.count('$backup/system/nginx-site"'), 2)
        self.assertEqual(RUNBOOK.count('$backup/system/logrotate"'), 2)


if __name__ == "__main__":
    unittest.main()
