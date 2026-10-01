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
        "consent_version": "2026-10-01-groq",
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

    def __init__(self, body):
        self._body = body

    def read(self, _limit):
        return self._body


class FakeConnection:
    def __init__(self, host, timeout, response_body):
        self.host = host
        self.timeout = timeout
        self.sock = FakeSocket()
        self.request_args = None
        self.closed = False
        self._response_body = response_body

    def connect(self):
        return None

    def request(self, method, path, body, headers):
        self.request_args = (method, path, body, headers)

    def getresponse(self):
        return FakeResponse(self._response_body)

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

    def test_provider_factory_defaults_to_groq(self):
        env = {
            "GROQ_API_KEY": "test-key",
            "GROQ_MODEL": "openai/gpt-oss-20b",
        }
        with patch.dict(os.environ, env, clear=True):
            provider = ai_provider.build_provider_from_env()
        self.assertIsInstance(provider, ai_provider.GroqProvider)

    def test_groq_requires_api_key(self):
        with patch.dict(os.environ, {"AI_PROVIDER": "groq"}, clear=True):
            with self.assertRaises(ai_provider.ProviderConfigurationError):
                ai_provider.build_provider_from_env()

    def test_groq_prompt_is_minimized_and_uses_bearer_auth(self):
        response = json.dumps(
            {"choices": [{"message": {"content": "Useful feedback"}}]}
        ).encode()
        connection = FakeConnection("unused", 1, response)

        def factory(host, timeout):
            connection.host = host
            connection.timeout = timeout
            return connection

        provider = ai_provider.GroqProvider(
            api_key="GROQ_SECRET_SENTINEL",
            model="openai/gpt-oss-20b",
            connection_factory=factory,
        )
        result = provider.generate_feedback(
            provider_request(), deadline=time.monotonic() + 10
        )
        self.assertEqual(result, "Useful feedback")
        _, path, raw_body, headers = connection.request_args
        sent = json.loads(raw_body.decode())
        prompt = sent["messages"][1]["content"]
        self.assertIn('"exercise": "push_up"', prompt)
        self.assertNotIn("schema_version", prompt)
        self.assertNotIn("consent_version", prompt)
        self.assertNotIn("workout_id", prompt)
        self.assertNotIn("routine_library", prompt)
        self.assertNotIn("SHOULD_NOT_ENTER_PROMPT", prompt)
        self.assertEqual(
            headers["authorization"], "Bearer GROQ_SECRET_SENTINEL"
        )
        self.assertEqual(connection.host, "api.groq.com")
        self.assertEqual(path, "/openai/v1/chat/completions")
        self.assertEqual(sent["model"], "openai/gpt-oss-20b")
        self.assertEqual(sent["temperature"], 0.6)
        self.assertEqual(sent["max_completion_tokens"], 512)
        self.assertEqual(sent["reasoning_effort"], "low")
        self.assertIs(sent["include_reasoning"], False)
        self.assertNotIn("max_tokens", sent)
        self.assertTrue(connection.closed)

    def test_groq_empty_and_overlong_responses_are_rejected(self):
        empty = json.dumps(
            {"choices": [{"message": {"content": "   "}}]}
        ).encode()
        with self.assertRaises(ai_provider.ProviderResponseInvalidError):
            ai_provider.parse_groq_response(empty)
        overlong = json.dumps(
            {"choices": [{"message": {"content": "x" * (ai_provider.MAX_FEEDBACK_CHARS + 1)}}]}
        ).encode()
        with self.assertRaises(ai_provider.ProviderResponseInvalidError):
            ai_provider.parse_groq_response(overlong)

    def test_legacy_gemini_still_requires_billing_enabled(self):
        env = {
            "AI_PROVIDER": "gemini",
            "GEMINI_API_KEY": "test-key",
            "GEMINI_MODEL": "test-model",
            "GEMINI_SERVICE_MODE": "billing_enabled",
        }
        with patch.dict(os.environ, env, clear=True):
            provider = ai_provider.build_provider_from_env()
        self.assertIsInstance(provider, ai_provider.GeminiProvider)

        env["GEMINI_SERVICE_MODE"] = "unpaid"
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaises(ai_provider.ProviderConfigurationError):
                ai_provider.build_provider_from_env()

    def test_unknown_provider_is_rejected(self):
        with patch.dict(os.environ, {"AI_PROVIDER": "other"}, clear=True):
            with self.assertRaises(ai_provider.ProviderConfigurationError):
                ai_provider.build_provider_from_env()


if __name__ == "__main__":
    unittest.main()
