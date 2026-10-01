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
APPLY = (BACKEND / "deploy" / "b7_apply.sh").read_text(encoding="utf-8")
ROLLBACK = (BACKEND / "deploy" / "b7_rollback.sh").read_text(encoding="utf-8")
DEPLOY_WORKFLOW = (
    PROJECT.parent / ".github" / "workflows" / "production-deploy.yml"
).read_text(encoding="utf-8")


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

    def test_runbook_uses_groq_provider_contract(self):
        self.assertIn("AI_PROVIDER=groq", RUNBOOK)
        self.assertIn("GROQ_API_KEY=<server secret>", RUNBOOK)
        self.assertIn("GROQ_MODEL=openai/gpt-oss-20b", RUNBOOK)
        self.assertIn("docs/groq-provider.md", RUNBOOK)
        self.assertNotIn("Exact production Gemini project verified Paid Tier", RUNBOOK)

    def test_runbook_keeps_secrets_out_of_repo(self):
        self.assertNotIn("BEGIN OPENSSH PRIVATE KEY", RUNBOOK)
        self.assertNotIn("gsk_", RUNBOOK)
        self.assertNotIn("Bearer gsk_", RUNBOOK)

    def test_deploy_guide_points_to_canonical_policy_and_groq(self):
        self.assertIn("../backend/static/privacy-policy.html", GUIDE)
        self.assertIn("../backend/docs/production-release.md", GUIDE)
        self.assertNotIn("/var/www/repcoach-ai", GUIDE)
        self.assertIn("AI_PROVIDER=groq", GUIDE)
        self.assertIn("GROQ_API_KEY", GUIDE)
        self.assertIn(
            "https://repcoach-ai.duckdns.org/privacy-policy.html",
            GUIDE,
        )

    def test_public_smoke_uses_shared_v2_fixture(self):
        self.assertIn("workout_feedback_v2.json", SMOKE)
        self.assertIn('fixture.get("schema_version") == 2', SMOKE)
        self.assertIn(
            'fixture.get("consent_version") == "2026-10-01-groq"',
            SMOKE,
        )
        self.assertIn("PRODUCTION_SMOKE_PASS", SMOKE)

    def test_public_smoke_checks_required_routes_and_secrets(self):
        for value in (
            '"/health"',
            '"/ready"',
            '"/privacy-policy.html"',
            '"/v1/workout-feedback"',
            "strict-transport-security",
            "x-content-type-options",
            "X-Request-ID",
            "GROQ_API_KEY",
            "api.groq.com",
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
        privacy_block = NGINX.split("location = /privacy-policy.html", 1)[1].split("}", 1)[0]
        self.assertIn("proxy_pass http://127.0.0.1:8787;", privacy_block)
        self.assertNotIn("alias ", privacy_block)
        self.assertIn("rotate 14", ROTATE)
        self.assertIn("WorkingDirectory=/home/nduythanh/apps/repcoach-backend", SERVICE)
        self.assertIn(
            "EnvironmentFile=/home/nduythanh/apps/repcoach-backend/.env",
            SERVICE,
        )

    def test_deploy_workflow_is_locked_and_pins_host_key(self):
        self.assertIn("B7_DEPLOY_APPROVED", DEPLOY_WORKFLOW)
        self.assertIn("DEPLOY_B7_2026_10_01", DEPLOY_WORKFLOW)
        self.assertIn("secrets.VPS_SSH_KEY", DEPLOY_WORKFLOW)
        self.assertIn("StrictHostKeyChecking=yes", DEPLOY_WORKFLOW)
        self.assertIn(
            "14.225.207.90 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG3oPFCAMe0W1WRqT5OjOHZo8SKDe5tFPeW9VQOYVmzF",
            DEPLOY_WORKFLOW,
        )
        self.assertNotIn("StrictHostKeyChecking=no", DEPLOY_WORKFLOW)
        self.assertIn("sudo -n true", DEPLOY_WORKFLOW)

    def test_apply_requires_groq_and_supports_manual_sudo(self):
        self.assertIn("AI_PROVIDER=groq", APPLY)
        self.assertIn("GROQ_API_KEY", APPLY)
        self.assertIn("GROQ_MODEL=openai/gpt-oss-20b", APPLY)
        self.assertNotIn("sudo -n true", APPLY)
        self.assertIn("python3 -m py_compile", APPLY)
        self.assertIn("missing deployment dependency: $cmd", APPLY)
        self.assertIn("for cmd in nginx logrotate systemctl ss curl", APPLY)
        self.assertLess(
            APPLY.index("for cmd in nginx logrotate systemctl ss curl"),
            APPLY.index('stamp="$(date -u +%Y%m%dT%H%M%SZ)"'),
        )
        self.assertIn("sudo nginx -t", APPLY)
        self.assertIn("backend did not become healthy within 10 seconds", APPLY)
        self.assertIn("curl -fsS --max-time 1 http://127.0.0.1:8787/health", APPLY)
        self.assertIn('nginx_dump="$(sudo nginx -T 2>/dev/null)"', APPLY)
        self.assertNotIn("sudo nginx -T 2>/dev/null | grep", APPLY)
        self.assertIn("POSTDEPLOY_BACKEND=PASS", APPLY)
        self.assertIn("POSTDEPLOY_NGINX=PASS", APPLY)
        self.assertIn("nginx effective config missing:", APPLY)
        self.assertIn("BACKUP_PATH=", APPLY)
        self.assertIn("Deploy failed; restoring pre-deploy backup", APPLY)

    def test_rollback_accepts_only_b7_backup_path(self):
        self.assertIn("/var/backups/repcoach-b7/*", ROLLBACK)
        self.assertIn("ROLLBACK_PASS", ROLLBACK)
        self.assertNotIn("sudo -n true", ROLLBACK)

    def test_backup_records_present_and_absent_state_for_exact_rollback(self):
        for marker in (
            "server.py.present",
            "server.py.absent",
            "static.present",
            "static.absent",
            "repcoach-backend.service.present",
            "repcoach-backend.service.absent",
            "nginx-site.present",
            "nginx-site.absent",
            "rate-limit.conf.present",
            "rate-limit.conf.absent",
            "logrotate.present",
            "logrotate.absent",
        ):
            self.assertIn(marker, APPLY)
            self.assertIn(marker, ROLLBACK)
        self.assertIn("sudo rm -f /etc/nginx/conf.d/repcoach-rate-limit.conf", APPLY)
        self.assertIn("sudo rm -f /etc/logrotate.d/repcoach-ai", APPLY)
        self.assertIn('sudo cp -a "$backup/app/server.py" "$app_dir/server.py"', APPLY)
        self.assertIn('sudo cp -a "$backup/app/ai_provider.py" "$app_dir/ai_provider.py"', APPLY)
        self.assertIn('sudo cp -a "$backup/app/static" "$app_dir/static"', APPLY)
        self.assertIn('sudo cp -a "$backup/app/server.py" "$app_dir/server.py"', ROLLBACK)
        self.assertIn('sudo cp -a "$backup/app/static" "$app_dir/static"', ROLLBACK)

    def test_runbook_documents_transactional_backup(self):
        self.assertIn("/var/backups/repcoach-b7/<UTC timestamp>", RUNBOOK)
        self.assertIn("b7_apply.sh", RUNBOOK)
        self.assertIn("b7_rollback.sh", RUNBOOK)


if __name__ == "__main__":
    unittest.main()
