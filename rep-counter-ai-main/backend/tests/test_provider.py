import json
import os
import sys
import time
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import ai_provider
import server


def provider_request():
    return {
        "schema_version": 2,
        "consent_version": "2026-10-01",
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
        "workout_id": "SHOULD_NOT_ENTER_PROMPT",
        "routine_library": "SHOULD_NOT_ENTER_PROMPT",
        "camera": "SHOULD_NOT_ENTER_PROMPT",
    }


class FakeProvider:
    def __init__(self, feedback="Fake feedback"):
        self.feedback = feedback
        self.requests = []

    def generate_feedback(self, request, *, deadline):
        self.requests.append((request, deadline))
        return self.feedback


class FakeSocket:
    def __init__(self):
        self.timeout = None

    def settimeout(self, timeout):
        self.timeout = timeout


class FakeResponse:
    status = 200

    def __init__(self, feedback="Useful feedback"):
        self._body = json.dumps(
            {"candidates": [{"content": {"parts": [{"text": feedback}]}}]}
        ).encode()

    def read(self, _limit):
        return self._body


class FakeConnection:
    def __init__(self, host, timeout):
        self.host = host
        self.timeout = timeout
        self.sock = FakeSocket()
        self.request_args = None
        self.closed = False

    def connect(self):
        return None

    def request(self, method, path, body, headers):
        self.request_args = (method, path, body, headers)

    def getresponse(self):
        return FakeResponse()

    def close(self):
        self.closed = True


class ProviderBoundaryTests(unittest.TestCase):
    def test_server_can_swap_in_fake_provider(self):
        fake = FakeProvider("Adapter works")
        with patch.object(server, "build_provider_from_env", return_value=fake):
            result = server.generate_feedback(
                {"exercise": "push_up", "locale": "en"},
                time.monotonic() + 5,
            )
        self.assertEqual(result, "Adapter works")
        self.assertEqual(fake.requests[0][0]["exercise"], "push_up")

    def test_provider_factory_requires_explicit_service_mode(self):
        env = {
            "AI_PROVIDER": "gemini",
            "GEMINI_API_KEY": "test-key",
            "GEMINI_MODEL": "test-model",
        }
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaises(ai_provider.ProviderConfigurationError):
                ai_provider.build_provider_from_env()

    def test_provider_factory_accepts_billing_enabled_mode(self):
        env = {
            "AI_PROVIDER": "gemini",
            "GEMINI_API_KEY": "test-key",
            "GEMINI_MODEL": "test-model",
            "GEMINI_SERVICE_MODE": "billing_enabled",
        }
        with patch.dict(os.environ, env, clear=True):
            provider = ai_provider.build_provider_from_env()
        self.assertIsInstance(provider, ai_provider.GeminiProvider)
        self.assertEqual(provider.service_mode, "billing_enabled")

    def test_provider_factory_rejects_unpaid_mode(self):
        env = {
            "AI_PROVIDER": "gemini",
            "GEMINI_API_KEY": "test-key",
            "GEMINI_MODEL": "test-model",
            "GEMINI_SERVICE_MODE": "unpaid",
        }
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaises(ai_provider.ProviderConfigurationError):
                ai_provider.build_provider_from_env()

    def test_provider_factory_rejects_unknown_mode(self):
        env = {
            "AI_PROVIDER": "gemini",
            "GEMINI_API_KEY": "test-key",
            "GEMINI_MODEL": "test-model",
            "GEMINI_SERVICE_MODE": "probably-paid",
        }
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaises(ai_provider.ProviderConfigurationError):
                ai_provider.build_provider_from_env()

    def test_provider_factory_rejects_unknown_provider(self):
        env = {
            "AI_PROVIDER": "other",
            "GEMINI_API_KEY": "test-key",
            "GEMINI_SERVICE_MODE": "billing_enabled",
        }
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaises(ai_provider.ProviderConfigurationError):
                ai_provider.build_provider_from_env()

    def test_gemini_prompt_is_minimized(self):
        connection = FakeConnection("unused", 1)

        def factory(host, timeout):
            connection.host = host
            connection.timeout = timeout
            return connection

        provider = ai_provider.GeminiProvider(
            api_key="SECRET_KEY_SENTINEL",
            model="test-model",
            service_mode="billing_enabled",
            connection_factory=factory,
        )
        result = provider.generate_feedback(
            provider_request(),
            deadline=time.monotonic() + 10,
        )

        self.assertEqual(result, "Useful feedback")
        _, path, raw_body, headers = connection.request_args
        sent = json.loads(raw_body.decode())
        prompt = sent["contents"][0]["parts"][0]["text"]
        self.assertIn('"exercise": "push_up"', prompt)
        self.assertNotIn("schema_version", prompt)
        self.assertNotIn("consent_version", prompt)
        self.assertNotIn("workout_id", prompt)
        self.assertNotIn("routine_library", prompt)
        self.assertNotIn("camera", prompt)
        self.assertNotIn("billing_enabled", prompt)
        self.assertEqual(headers["x-goog-api-key"], "SECRET_KEY_SENTINEL")
        self.assertEqual(
            connection.host, "generativelanguage.googleapis.com"
        )
        self.assertEqual(path, "/v1beta/models/test-model:generateContent")
        self.assertTrue(connection.closed)

    def test_overlong_feedback_is_rejected(self):
        overlong = "x" * (ai_provider.MAX_FEEDBACK_CHARS + 1)
        raw = json.dumps(
            {"candidates": [{"content": {"parts": [{"text": overlong}]}}]}
        ).encode()
        with self.assertRaises(ai_provider.ProviderResponseInvalidError):
            ai_provider.parse_provider_response(raw)

    def test_empty_feedback_is_rejected(self):
        raw = json.dumps(
            {"candidates": [{"content": {"parts": [{"text": "   "}]}}]}
        ).encode()
        with self.assertRaises(ai_provider.ProviderResponseInvalidError):
            ai_provider.parse_provider_response(raw)


if __name__ == "__main__":
    unittest.main()
