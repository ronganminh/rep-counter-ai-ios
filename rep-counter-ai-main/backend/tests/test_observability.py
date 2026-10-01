import http.client
import json
import re
import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server


REQUEST_ID_RE = re.compile(r"^[0-9a-f]{32}$")


class ObservabilityHttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd = server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.port = cls.httpd.server_address[1]
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()
        cls.thread.join(timeout=2)

    def request(self, path, *, method="GET", body=None, headers=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        hdrs = dict(headers or {})
        if body is not None and "content-type" not in {
            key.lower(): value for key, value in hdrs.items()
        }:
            hdrs["content-type"] = "application/json"
        conn.request(method, path, body=body, headers=hdrs)
        response = conn.getresponse()
        raw = response.read()
        result = (
            response.status,
            {key.lower(): value for key, value in response.getheaders()},
            json.loads(raw.decode("utf-8")),
        )
        conn.close()
        return result

    def test_health_is_process_only_and_does_not_resolve_provider(self):
        with patch.object(server, "build_provider_from_env") as build:
            status, headers, body = self.request("/health")
        self.assertEqual(status, 200)
        self.assertEqual(body, {"status": "ok"})
        self.assertRegex(headers["x-request-id"], REQUEST_ID_RE)
        build.assert_not_called()

    def test_readiness_reports_ready_without_external_provider_call(self):
        sentinel = object()
        with patch.object(
            server, "build_provider_from_env", return_value=sentinel
        ) as build:
            status, headers, body = self.request("/ready")
        self.assertEqual(status, 200)
        self.assertEqual(body, {"status": "ready"})
        self.assertRegex(headers["x-request-id"], REQUEST_ID_RE)
        build.assert_called_once_with()

    def test_readiness_reports_not_ready_without_exposing_config(self):
        with patch.object(
            server,
            "build_provider_from_env",
            side_effect=server.ProviderConfigurationError(),
        ):
            status, _, body = self.request("/ready")
        self.assertEqual(status, 503)
        self.assertEqual(body, {"status": "not_ready"})
        serialized = json.dumps(body)
        self.assertNotIn("GEMINI_API_KEY", serialized)
        self.assertNotIn("GEMINI_SERVICE_MODE", serialized)

    def _request_with_captured_log(self, path, *, headers=None):
        logged = []
        log_ready = threading.Event()

        def capture_print(*args, **kwargs):
            del kwargs
            if args:
                logged.append(str(args[0]))
                log_ready.set()

        with patch("builtins.print", side_effect=capture_print):
            response = self.request(path, headers=headers)
            self.assertTrue(log_ready.wait(1), "backend log event was not emitted")
        self.assertTrue(logged)
        return response, json.loads(logged[-1])

    def test_request_id_is_generated_returned_and_logged(self):
        (status, headers, body), event = self._request_with_captured_log("/health")
        self.assertEqual(status, 200)
        self.assertEqual(body, {"status": "ok"})
        request_id = headers["x-request-id"]
        self.assertRegex(request_id, REQUEST_ID_RE)

        self.assertEqual(event["request_id"], request_id)
        self.assertEqual(event["route"], "/health")
        self.assertEqual(event["status"], 200)
        self.assertIn("duration_ms", event)
        self.assertNotIn("latency_ms", event)

    def test_valid_upstream_request_id_is_propagated(self):
        upstream = "a" * 32
        (status, headers, _), event = self._request_with_captured_log(
            "/health", headers={"X-Request-ID": upstream}
        )
        self.assertEqual(status, 200)
        self.assertEqual(headers["x-request-id"], upstream)
        self.assertEqual(event["request_id"], upstream)

    def test_invalid_request_id_is_replaced_not_logged(self):
        incoming = "USER_TRACKING_SENTINEL"
        (status, headers, _), event = self._request_with_captured_log(
            "/health", headers={"X-Request-ID": incoming}
        )
        self.assertEqual(status, 200)
        self.assertRegex(headers["x-request-id"], REQUEST_ID_RE)
        self.assertNotEqual(headers["x-request-id"], incoming)
        self.assertNotIn(incoming, json.dumps(event))

    def test_options_has_no_cors_allow_origin(self):
        status, headers, body = self.request(
            "/v1/workout-feedback", method="OPTIONS"
        )
        self.assertEqual(status, 405)
        self.assertEqual(body, {"error": "INVALID_REQUEST"})
        self.assertEqual(headers.get("allow"), "POST")
        self.assertNotIn("access-control-allow-origin", headers)

    def test_unknown_route_has_request_id_and_no_cors(self):
        status, headers, body = self.request("/not-a-route")
        self.assertEqual(status, 404)
        self.assertEqual(body, {"error": "NOT_FOUND"})
        self.assertRegex(headers["x-request-id"], REQUEST_ID_RE)
        self.assertNotIn("access-control-allow-origin", headers)


class RequestIdUnitTests(unittest.TestCase):
    def test_request_id_accepts_only_bounded_hex(self):
        value = "ABCDEF0123456789ABCDEF0123456789"
        self.assertEqual(
            server.normalize_request_id(value),
            "abcdef0123456789abcdef0123456789",
        )

    def test_request_id_rejects_arbitrary_tracking_value(self):
        generated = server.normalize_request_id("customer-123")
        self.assertRegex(generated, REQUEST_ID_RE)
        self.assertNotEqual(generated, "customer-123")


if __name__ == "__main__":
    unittest.main()
