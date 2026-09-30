"""Minimal Gemini proxy: keep the API key off-device and accept summary data only."""
from __future__ import annotations

import json
import math
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


MAX_BODY_BYTES = 16_384
RESPONSE_SCHEMA_VERSION = 1
SUPPORTED_REQUEST_SCHEMA_VERSIONS = {1, 2}
SUPPORTED_EXERCISES = {"push_up", "pull_up", "curl", "overhead_extension"}
SUPPORTED_LOCALES = {"vi", "en"}

CORE_FIELDS = {
    "exercise",
    "duration_seconds",
    "reps",
    "sets",
    "target_reps",
    "goal_reached",
    "placement_score",
    "pose_frames",
    "pose_lost_frames",
    "locale",
}
QUALITY_FIELDS = {
    "flagged_reps",
    "avg_rep_sec",
    "avg_amplitude",
    "amplitude_drop_percent",
    "left_right_diff_percent",
    "quality_score",
    "has_enough_data",
}
METADATA_FIELDS = {"schema_version", "consent_version"}
PROMPT_FIELDS = (
    "exercise",
    "duration_seconds",
    "reps",
    "sets",
    "target_reps",
    "goal_reached",
    "placement_score",
    "pose_frames",
    "pose_lost_frames",
    "flagged_reps",
    "avg_rep_sec",
    "avg_amplitude",
    "amplitude_drop_percent",
    "left_right_diff_percent",
    "quality_score",
    "has_enough_data",
)


class RequestValidationError(ValueError):
    """The client payload does not match a supported workout-feedback schema."""


def load_env() -> None:
    path = Path(__file__).with_name(".env")
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def _require_int(
    payload: dict,
    field: str,
    *,
    minimum: int,
    maximum: int,
    nullable: bool = False,
) -> int | None:
    value = payload.get(field)
    if value is None and nullable:
        return None
    if type(value) is not int or not minimum <= value <= maximum:
        raise RequestValidationError(field)
    return value


def _require_number(
    payload: dict,
    field: str,
    *,
    minimum: float,
    maximum: float,
) -> float:
    value = payload.get(field)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise RequestValidationError(field)
    number = float(value)
    if not math.isfinite(number) or not minimum <= number <= maximum:
        raise RequestValidationError(field)
    return number


def _require_bool(payload: dict, field: str) -> bool:
    value = payload.get(field)
    if type(value) is not bool:
        raise RequestValidationError(field)
    return value


def _require_string(
    payload: dict,
    field: str,
    *,
    minimum_length: int = 1,
    maximum_length: int = 64,
) -> str:
    value = payload.get(field)
    if not isinstance(value, str):
        raise RequestValidationError(field)
    if not minimum_length <= len(value) <= maximum_length or value.strip() != value:
        raise RequestValidationError(field)
    return value


def normalize_workout_request(workout: object) -> dict:
    """Validate v1/v2 payloads and normalize legacy unversioned payloads to v1."""
    if not isinstance(workout, dict):
        raise RequestValidationError("json_object_required")

    raw_version = workout.get("schema_version", 1)
    if type(raw_version) is not int or raw_version not in SUPPORTED_REQUEST_SCHEMA_VERSIONS:
        raise RequestValidationError("schema_version")
    schema_version = raw_version

    allowed_fields = set(CORE_FIELDS | QUALITY_FIELDS | {"schema_version"})
    if schema_version == 2:
        allowed_fields.add("consent_version")

    unknown = set(workout) - allowed_fields
    if unknown:
        raise RequestValidationError("unknown_fields")

    missing = CORE_FIELDS - set(workout)
    if missing:
        raise RequestValidationError("missing_fields")
    if schema_version == 2 and "consent_version" not in workout:
        raise RequestValidationError("consent_version")

    exercise = _require_string(workout, "exercise", maximum_length=32)
    if exercise not in SUPPORTED_EXERCISES:
        raise RequestValidationError("exercise")

    locale = _require_string(workout, "locale", minimum_length=2, maximum_length=2)
    if locale not in SUPPORTED_LOCALES:
        raise RequestValidationError("locale")

    _require_int(workout, "duration_seconds", minimum=0, maximum=604_800)
    reps = _require_int(workout, "reps", minimum=0, maximum=100_000)
    _require_int(workout, "sets", minimum=0, maximum=10_000)
    _require_int(workout, "target_reps", minimum=0, maximum=100_000, nullable=True)
    _require_bool(workout, "goal_reached")
    _require_int(workout, "placement_score", minimum=0, maximum=100)
    pose_frames = _require_int(workout, "pose_frames", minimum=0, maximum=10_000_000)
    pose_lost_frames = _require_int(
        workout, "pose_lost_frames", minimum=0, maximum=10_000_000
    )
    if pose_lost_frames > pose_frames:
        raise RequestValidationError("pose_lost_frames")

    if "flagged_reps" in workout:
        flagged_reps = _require_int(workout, "flagged_reps", minimum=0, maximum=100_000)
        if flagged_reps > reps:
            raise RequestValidationError("flagged_reps")
    if "avg_rep_sec" in workout:
        _require_number(workout, "avg_rep_sec", minimum=0, maximum=3_600)
    if "avg_amplitude" in workout:
        _require_number(workout, "avg_amplitude", minimum=0, maximum=10_000)
    if "amplitude_drop_percent" in workout:
        _require_number(workout, "amplitude_drop_percent", minimum=0, maximum=10_000)
    if "left_right_diff_percent" in workout:
        _require_number(workout, "left_right_diff_percent", minimum=0, maximum=10_000)
    if "quality_score" in workout:
        _require_int(workout, "quality_score", minimum=0, maximum=100)
    if "has_enough_data" in workout:
        _require_bool(workout, "has_enough_data")

    normalized = dict(workout)
    normalized["schema_version"] = schema_version
    if schema_version == 2:
        _require_string(workout, "consent_version", maximum_length=64)
    return normalized


def parse_workout_request(raw_body: bytes) -> dict:
    try:
        payload = json.loads(raw_body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RequestValidationError("malformed_json") from error
    return normalize_workout_request(payload)


def prompt_summary(workout: dict) -> dict:
    """Only workout summary fields enter the Gemini prompt; contract metadata does not."""
    return {key: workout[key] for key in PROMPT_FIELDS if key in workout}


def feedback_response(feedback: str) -> dict:
    return {"schema_version": RESPONSE_SCHEMA_VERSION, "feedback": feedback}


load_env()


class Handler(BaseHTTPRequestHandler):
    def reply(self, status: int, data: dict) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path != "/health":
            self.reply(404, {"error": "not_found"})
            return
        self.reply(200, {"ok": True, "service": "repcoach-ai"})

    def do_POST(self) -> None:
        if self.path != "/v1/workout-feedback":
            self.reply(404, {"error": "not_found"})
            return
        key = os.getenv("GEMINI_API_KEY", "").strip()
        if not key:
            self.reply(503, {"error": "GEMINI_API_KEY is missing"})
            return
        try:
            declared_length = int(self.headers.get("content-length", "0"))
            if declared_length <= 0 or declared_length > MAX_BODY_BYTES:
                self.reply(413, {"error": "invalid_request_size"})
                return
            workout = parse_workout_request(self.rfile.read(declared_length))
            locale = workout["locale"]
            PROMPTS = {
                "vi": (
                    "Bạn là HLV thể hình thân thiện. Nhận xét buổi hít đất bằng TIẾNG VIỆT, "
                    "2-4 câu, ngắn gọn và có một lời khuyên an toàn, khả thi cho buổi sau. "
                    "Không chẩn đoán y khoa, không khẳng định kỹ thuật hoàn hảo chỉ từ thống kê. "
                    "Chỉ dùng số liệu được cung cấp, không suy đoán lại số rep hay điểm số. "
                    "Nếu has_enough_data là false hoặc thiếu số liệu chất lượng, nói rõ chưa đủ "
                    "dữ liệu để đánh giá kỹ thuật thay vì đoán. "
                    "Nếu pose_lost_frames chiếm tỉ lệ lớn so với pose_frames, ưu tiên khuyên "
                    "chỉnh góc đặt camera thay vì phê bình kỹ thuật.\n"
                ),
                "en": (
                    "You are a friendly strength coach. Comment on this push-up session "
                    "in ENGLISH ONLY, 2-4 short sentences, ending with one safe, actionable "
                    "tip for next time. Do not diagnose or give medical advice, and do not "
                    "claim the form is perfect based on statistics alone. "
                    "Use only the numbers provided; never recompute or guess rep counts or "
                    "scores. If has_enough_data is false or quality numbers are missing, say "
                    "plainly that there is not enough data to judge technique. If "
                    "pose_lost_frames is a large share of pose_frames, prioritise advice about "
                    "camera placement over criticising technique.\n"
                ),
            }
            prompt = PROMPTS[locale] + json.dumps(prompt_summary(workout), ensure_ascii=False)
            model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"temperature": 0.4, "maxOutputTokens": 220},
            }
            req = Request(
                url,
                data=json.dumps(payload).encode(),
                method="POST",
                headers={"content-type": "application/json", "x-goog-api-key": key},
            )
            with urlopen(req, timeout=20) as response:
                result = json.load(response)
            feedback = result["candidates"][0]["content"]["parts"][0]["text"].strip()
            self.reply(200, feedback_response(feedback))
        except RequestValidationError:
            self.reply(400, {"error": "invalid_request"})
        except (ValueError, KeyError) as error:
            self.reply(400, {"error": str(error)})
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")[:500]
            self.reply(502, {"error": "gemini_error", "detail": detail})
        except Exception as error:
            self.reply(502, {"error": type(error).__name__})

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"[backend] {fmt % args}")


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8787"))
    host = os.getenv("BIND_HOST", "127.0.0.1")
    print(f"Workout AI backend: http://{host}:{port}")
    ThreadingHTTPServer((host, port), Handler).serve_forever()
