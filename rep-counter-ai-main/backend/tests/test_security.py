import contextlib
import http.client
import io
import json
import os
import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server


def valid_v2():
    return {
        "schema_version": 2,
        "consent_version": "CONSENT_SENTINEL_2026_10_01",
        "exercise": "push_up",
        "duration_seconds": 120,
        "reps": 20,
        "sets": 2,
        "target_reps": 20,
        "goal_reached": True,
        "placement_score": 90,
        "pose_frames": 1000,
        "pose_lost_frames": 20,
        "flagged_reps": 1,
        "avg_rep_sec": 1.5,
        "avg_amplitude": 50.0,
        "amplitude_drop_percent": 5.0,
        "left_right_diff_percent": 4.0,
        "quality_score": 88,
        "has_enough_data": True,
        "locale": "en",
    }


class ApiSecurityTests(unittest.TestCase):
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

    def setUp(self):
        self.old_key = os.environ.get("GEMINI_API_KEY")
        self.old_mode = os.environ.get("GEMINI_SERVICE_MODE")
        os.environ["GEMINI_API_KEY"] = "TEST_API_KEY_SENTINEL"
        os.environ["GEMINI_SERVICE_MODE"] = "billing_enabled"

    def tearDown(self):
        if self.old_key is None:
            os.environ.pop("GEMINI_API_KEY", None)
        else:
            os.environ["GEMINI_API_KEY"] = self.old_key
        if self.old_mode is None:
            os.environ.pop("GEMINI_SERVICE_MODE", None)
        else:
            os.environ["GEMINI_SERVICE_MODE"] = self.old_mode

    def request(self, method="POST", body=None, headers=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        if isinstance(body, dict):
            body = json.dumps(body)
        hdrs = {"content-type": "application/json"}
        if headers:
            hdrs.update(headers)
        conn.request(method, "/v1/workout-feedback", body=body, headers=hdrs)
        response = conn.getresponse()
        raw = response.read()
        result = (
            response.status,
            dict(response.getheaders()),
            json.loads(raw.decode("utf-8")),
        )
        conn.close()
        return result

    def test_success_is_versioned_and_logs_metadata_only(self):
        stream = io.StringIO()
        with patch.object(
            server, "generate_feedback", return_value="FEEDBACK_SENTINEL"
        ), contextlib.redirect_stdout(stream):
            status, _, body = self.request(body=valid_v2())
        self.assertEqual(status, 200)
        self.assertEqual(
            body, {"schema_version": 1, "feedback": "FEEDBACK_SENTINEL"}
        )
        logged = stream.getvalue()
        self.assertIn('"status":200', logged)
        self.assertIn('"request_size":', logged)
        self.assertNotIn("CONSENT_SENTINEL_2026_10_01", logged)
        self.assertNotIn("FEEDBACK_SENTINEL", logged)
        self.assertNotIn("TEST_API_KEY_SENTINEL", logged)

    def test_oversized_body_is_rejected_before_provider(self):
        oversized = "x" * (server.MAX_BODY_BYTES + 1)
        with patch.object(server, "generate_feedback") as generate:
            status, _, body = self.request(body=oversized)
        self.assertEqual(status, 413)
        self.assertEqual(body, {"error": "INVALID_REQUEST"})
        generate.assert_not_called()

    def test_method_rejection_is_json_405(self):
        status, headers, body = self.request(method="GET")
        self.assertEqual(status, 405)
        self.assertEqual(body, {"error": "INVALID_REQUEST"})
        self.assertEqual(headers.get("allow"), "POST")

    def test_provider_timeout_maps_to_ai_timeout(self):
        with patch.object(
            server, "generate_feedback", side_effect=server.ProviderTimeoutError()
        ):
            status, _, body = self.request(body=valid_v2())
        self.assertEqual((status, body), (504, {"error": "AI_TIMEOUT"}))

    def test_provider_429_maps_to_ai_unavailable(self):
        with patch.object(
            server,
            "generate_feedback",
            side_effect=server.ProviderUnavailableError("4xx"),
        ):
            status, _, body = self.request(body=valid_v2())
        self.assertEqual((status, body), (503, {"error": "AI_UNAVAILABLE"}))

    def test_provider_5xx_maps_to_ai_unavailable(self):
        with patch.object(
            server,
            "generate_feedback",
            side_effect=server.ProviderUnavailableError("5xx"),
        ):
            status, _, body = self.request(body=valid_v2())
        self.assertEqual((status, body), (503, {"error": "AI_UNAVAILABLE"}))

    def test_malformed_provider_response_maps_to_ai_response_invalid(self):
        with patch.object(
            server,
            "generate_feedback",
            side_effect=server.ProviderResponseInvalidError(),
        ):
            status, _, body = self.request(body=valid_v2())
        self.assertEqual((status, body), (502, {"error": "AI_RESPONSE_INVALID"}))

    def test_missing_key_does_not_expose_configuration(self):
        os.environ.pop("GEMINI_API_KEY", None)
        status, _, body = self.request(body=valid_v2())
        self.assertEqual((status, body), (503, {"error": "AI_UNAVAILABLE"}))
        self.assertNotIn("GEMINI_API_KEY", json.dumps(body))

    def test_missing_service_mode_does_not_expose_configuration(self):
        os.environ.pop("GEMINI_SERVICE_MODE", None)
        status, _, body = self.request(body=valid_v2())
        self.assertEqual((status, body), (503, {"error": "AI_UNAVAILABLE"}))
        self.assertNotIn("GEMINI_SERVICE_MODE", json.dumps(body))

    def test_malformed_json_is_invalid_request(self):
        status, _, body = self.request(body='{"reps":')
        self.assertEqual((status, body), (400, {"error": "INVALID_REQUEST"}))

    def test_wrong_content_type_is_invalid_request(self):
        status, _, body = self.request(
            body=json.dumps(valid_v2()), headers={"content-type": "text/plain"}
        )
        self.assertEqual((status, body), (400, {"error": "INVALID_REQUEST"}))

    def test_unexpected_error_maps_to_server_error(self):
        with patch.object(
            server,
            "generate_feedback",
            side_effect=RuntimeError("SECRET_INTERNAL_DETAIL"),
        ):
            status, _, body = self.request(body=valid_v2())
        self.assertEqual((status, body), (500, {"error": "SERVER_ERROR"}))
        self.assertNotIn("SECRET_INTERNAL_DETAIL", json.dumps(body))


class ProviderResponseTests(unittest.TestCase):
    def test_valid_provider_response(self):
        raw = json.dumps(
            {"candidates": [{"content": {"parts": [{"text": "Useful feedback"}]}}]}
        ).encode()
        self.assertEqual(server.parse_provider_response(raw), "Useful feedback")

    def test_invalid_json_is_rejected(self):
        with self.assertRaises(server.ProviderResponseInvalidError):
            server.parse_provider_response(b"not-json")

    def test_missing_candidate_text_is_rejected(self):
        with self.assertRaises(server.ProviderResponseInvalidError):
            server.parse_provider_response(b"{}")

    def test_empty_feedback_is_rejected(self):
        raw = json.dumps(
            {"candidates": [{"content": {"parts": [{"text": "   "}]}}]}
        ).encode()
        with self.assertRaises(server.ProviderResponseInvalidError):
            server.parse_provider_response(raw)


if __name__ == "__main__":
    unittest.main()
