import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NGINX = (ROOT / "deploy" / "repcoach-ai.nginx").read_text(encoding="utf-8")
RATE = (ROOT / "deploy" / "repcoach-rate-limit.conf").read_text(encoding="utf-8")
ROTATE = (ROOT / "deploy" / "repcoach-ai.logrotate").read_text(encoding="utf-8")


class DeployConfigTests(unittest.TestCase):
    def test_body_limit_matches_app_limit(self):
        self.assertIn("client_max_body_size 16k;", NGINX)

    def test_privacy_policy_route_is_static_html_utf8(self):
        self.assertIn("location = /privacy-policy.html", NGINX)
        self.assertIn(
            "alias /home/nduythanh/apps/repcoach-backend/static/privacy-policy.html;",
            NGINX,
        )
        self.assertIn("default_type text/html;", NGINX)
        self.assertIn("charset utf-8;", NGINX)

    def test_health_and_readiness_are_proxied_with_request_ids(self):
        self.assertIn("location = /health", NGINX)
        self.assertIn("location = /ready", NGINX)
        self.assertGreaterEqual(
            NGINX.count("proxy_set_header X-Request-ID $request_id;"), 3
        )

    def test_nginx_generated_api_errors_return_request_id(self):
        self.assertGreaterEqual(
            NGINX.count("add_header X-Request-ID $request_id always;"), 3
        )

    def test_rate_limit_has_json_429_and_retry_after(self):
        self.assertIn("limit_req_status 429;", NGINX)
        self.assertIn("return 429 '{\"error\":\"RATE_LIMITED\"}';", NGINX)
        self.assertIn('add_header Retry-After "60" always;', NGINX)

    def test_feedback_is_post_only_with_json_405(self):
        self.assertIn("if ($request_method != POST) { return 405; }", NGINX)
        self.assertIn("return 405 '{\"error\":\"INVALID_REQUEST\"}';", NGINX)

    def test_proxy_timeout_budget_is_bounded(self):
        self.assertIn("proxy_connect_timeout 2s;", NGINX)
        self.assertIn("proxy_send_timeout 5s;", NGINX)
        self.assertIn("proxy_read_timeout 22s;", NGINX)

    def test_access_log_format_is_metadata_only(self):
        self.assertIn("log_format repcoach_meta", RATE)
        self.assertIn("request_id=$request_id", RATE)
        forbidden = (
            "$request_body",
            "$http_authorization",
            "$http_referer",
            "$http_user_agent",
        )
        for value in forbidden:
            self.assertNotIn(value, RATE)

    def test_log_rotation_is_finite(self):
        self.assertIn("daily", ROTATE)
        self.assertIn("rotate 14", ROTATE)
        self.assertIn("compress", ROTATE)


if __name__ == "__main__":
    unittest.main()
