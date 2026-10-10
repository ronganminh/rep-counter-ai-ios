import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server


CURRENT_CONSENT_VERSION = "2026-10-01-groq"


def valid_v2():
    return {
        "schema_version": 2,
        "consent_version": CURRENT_CONSENT_VERSION,
        "exercise": "push_up",
        "duration_seconds": 780,
        "reps": 28,
        "sets": 3,
        "target_reps": 30,
        "goal_reached": False,
        "placement_score": 91,
        "pose_frames": 3901,
        "pose_lost_frames": 84,
        "flagged_reps": 4,
        "avg_rep_sec": 1.6,
        "avg_amplitude": 52.0,
        "amplitude_drop_percent": 8.0,
        "left_right_diff_percent": 5.0,
        "quality_score": 84,
        "has_enough_data": True,
        "locale": "vi",
    }


class ValidationTests(unittest.TestCase):
    def test_valid_v2_with_current_consent(self):
        normalized = server.normalize_workout_request(valid_v2())
        self.assertEqual(normalized["schema_version"], 2)
        self.assertEqual(
            normalized["consent_version"],
            CURRENT_CONSENT_VERSION,
        )

    def test_unversioned_legacy_is_rejected(self):
        payload = valid_v2()
        payload.pop("schema_version")
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_explicit_v1_is_rejected(self):
        payload = valid_v2()
        payload["schema_version"] = 1
        payload.pop("consent_version")
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_v2_requires_consent_version(self):
        payload = valid_v2()
        payload.pop("consent_version")
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_v2_rejects_stale_consent_version(self):
        payload = valid_v2()
        payload["consent_version"] = "2026-09-30-gemini"
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_v2_rejects_arbitrary_nonempty_consent_version(self):
        payload = valid_v2()
        payload["consent_version"] = "some-nonempty-value"
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_missing_required_field(self):
        payload = valid_v2()
        payload.pop("reps")
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_unknown_field(self):
        payload = valid_v2()
        payload["camera_frame"] = "not-allowed"
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_wrong_type(self):
        payload = valid_v2()
        payload["reps"] = "28"
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_bool_is_not_accepted_as_integer(self):
        payload = valid_v2()
        payload["reps"] = True
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_negative_reps(self):
        payload = valid_v2()
        payload["reps"] = -1
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_negative_duration(self):
        payload = valid_v2()
        payload["duration_seconds"] = -1
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_invalid_locale(self):
        payload = valid_v2()
        payload["locale"] = "fr"
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_invalid_exercise(self):
        payload = valid_v2()
        payload["exercise"] = "bench_press"
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_all_current_app_exercises_are_allowed(self):
        for exercise in ("push_up", "pull_up", "curl", "overhead_extension"):
            payload = valid_v2()
            payload["exercise"] = exercise
            self.assertEqual(
                server.normalize_workout_request(payload)["exercise"],
                exercise,
            )

    def test_pose_lost_frames_cannot_exceed_pose_frames(self):
        payload = valid_v2()
        payload["pose_lost_frames"] = payload["pose_frames"] + 1
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_flagged_reps_cannot_exceed_reps(self):
        payload = valid_v2()
        payload["flagged_reps"] = payload["reps"] + 1
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_malformed_json(self):
        with self.assertRaises(server.RequestValidationError):
            server.parse_workout_request(b'{"reps":')

    def test_json_root_must_be_object(self):
        with self.assertRaises(server.RequestValidationError):
            server.parse_workout_request(b"[]")

    def test_oversized_numeric_value(self):
        payload = valid_v2()
        payload["reps"] = 100_001
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_non_finite_numeric_value(self):
        payload = valid_v2()
        payload["avg_amplitude"] = float("inf")
        with self.assertRaises(server.RequestValidationError):
            server.normalize_workout_request(payload)

    def test_contract_metadata_is_not_sent_to_prompt(self):
        summary = server.prompt_summary(valid_v2())
        self.assertNotIn("schema_version", summary)
        self.assertNotIn("consent_version", summary)
        self.assertNotIn("locale", summary)
        self.assertEqual(summary["exercise"], "push_up")

    def test_response_schema_is_stable(self):
        self.assertEqual(
            server.feedback_response("Good session"),
            {"schema_version": 1, "feedback": "Good session"},
        )

    def test_serialized_valid_v2_round_trip(self):
        payload = valid_v2()
        normalized = server.parse_workout_request(
            json.dumps(payload).encode("utf-8")
        )
        self.assertEqual(normalized, payload)


if __name__ == "__main__":
    unittest.main()
