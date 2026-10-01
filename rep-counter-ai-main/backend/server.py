"""RepCoach workout-feedback API with strict contracts and swappable AI providers."""
from __future__ import annotations

import json
import math
import os
import re
import secrets
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from ai_provider import (
    ProviderConfigurationError,
    ProviderResponseInvalidError,
    ProviderTimeoutError,
    ProviderUnavailableError,
    build_provider_from_env,
    parse_provider_response,
    prompt_summary,
)


MAX_BODY_BYTES = 16_384
TOTAL_REQUEST_BUDGET_SECONDS = 20
RESPONSE_SCHEMA_VERSION = 1
SUPPORTED_REQUEST_SCHEMA_VERSIONS = {1, 2}
SUPPORTED_EXERCISES = {"push_up", "pull_up", "curl", "overhead_extension"}
SUPPORTED_LOCALES = {"vi", "en"}
REQUEST_ID_PATTERN = re.compile(r"^[0-9a-fA-F]{32}$")
PRIVACY_POLICY_PATH = Path(__file__).with_name("static") / "privacy-policy.html"

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
    if set(workout) - allowed_fields:
        raise RequestValidationError("unknown_fields")

    if CORE_FIELDS - set(workout):
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


def feedback_response(feedback: str) -> dict:
    return {"schema_version": RESPONSE_SCHEMA_VERSION, "feedback": feedback}


def error_response(code: str) -> dict:
    return {"error": code}


def normalize_request_id(value: object) -> str:
    """Accept only the bounded Nginx request-id format; otherwise generate one."""
    if isinstance(value, str) and REQUEST_ID_PATTERN.fullmatch(value):
        return value.lower()
    return secrets.token_hex(16)


def provider_configuration_ready() -> bool:
    """Validate required provider configuration without making an external AI call."""
    try:
        build_provider_from_env()
    except ProviderConfigurationError:
        return False
    return True


def generate_feedback(workout: dict, deadline: float) -> str:
    """Resolve the configured provider and generate feedback through its adapter."""
    provider = build_provider_from_env()
    return provider.generate_feedback(workout, deadline=deadline)


def _request_size_bucket(length: int | None) -> str | None:
    if length is None:
        return None
    if length < 1_024:
        return "lt_1k"
    if length < 4_096:
        return "1k_4k"
    if length <= MAX_BODY_BYTES:
        return "4k_16k"
    return "over_limit"


load_env()


class Handler(BaseHTTPRequestHandler):
    server_version = "RepCoachBackend"
    sys_version = ""

    def handle_one_request(self) -> None:
        self._started_at = time.monotonic()
        self._request_id = None
        self._request_size_bucket = None
        self._provider_status_class = None
        super().handle_one_request()

    def _ensure_request_id(self) -> str:
        if self._request_id is None:
            incoming = self.headers.get("x-request-id") if hasattr(self, "headers") else None
            self._request_id = normalize_request_id(incoming)
        return self._request_id

    def reply(
        self,
        status: int,
        data: dict,
        *,
        headers: dict[str, str] | None = None,
    ) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        request_id = self._ensure_request_id()
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.send_header("cache-control", "no-store")
        self.send_header("x-request-id", request_id)
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)
        self._log_response(status, data.get("error"))

    def reply_content(
        self,
        status: int,
        body: bytes,
        *,
        content_type: str,
    ) -> None:
        request_id = self._ensure_request_id()
        self.send_response(status)
        self.send_header("content-type", content_type)
        self.send_header("content-length", str(len(body)))
        self.send_header("cache-control", "no-store")
        self.send_header("x-request-id", request_id)
        self.end_headers()
        self.wfile.write(body)
        self._log_response(status)

    def _log_response(self, status: int, error_code: object = None) -> None:
        event = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "request_id": self._ensure_request_id(),
            "route": self.path.split("?", 1)[0],
            "method": self.command,
            "status": status,
            "duration_ms": round((time.monotonic() - self._started_at) * 1000),
        }
        if self._request_size_bucket is not None:
            event["request_size"] = self._request_size_bucket
        if isinstance(error_code, str):
            event["error_code"] = error_code
        if self._provider_status_class is not None:
            event["provider_status_class"] = self._provider_status_class
        print(json.dumps(event, separators=(",", ":"), ensure_ascii=True), flush=True)

    def _invalid_method(self) -> None:
        if self.path.split("?", 1)[0] == "/v1/workout-feedback":
            self.reply(405, error_response("INVALID_REQUEST"), headers={"allow": "POST"})
        else:
            self.reply(404, error_response("NOT_FOUND"))

    def do_GET(self) -> None:
        route = self.path.split("?", 1)[0]
        if route == "/health":
            self.reply(200, {"status": "ok"})
            return
        if route == "/privacy-policy.html":
            try:
                body = PRIVACY_POLICY_PATH.read_bytes()
            except OSError:
                self.reply(500, error_response("SERVER_ERROR"))
                return
            self.reply_content(
                200,
                body,
                content_type="text/html; charset=utf-8",
            )
            return
        if route == "/ready":
            if provider_configuration_ready():
                self.reply(200, {"status": "ready"})
            else:
                self._provider_status_class = "configuration"
                self.reply(503, {"status": "not_ready"})
            return
        if route == "/v1/workout-feedback":
            self._invalid_method()
            return
        self.reply(404, error_response("NOT_FOUND"))

    def do_POST(self) -> None:
        route = self.path.split("?", 1)[0]
        if route != "/v1/workout-feedback":
            self.reply(404, error_response("NOT_FOUND"))
            return
        try:
            content_type = self.headers.get_content_type()
            if content_type != "application/json":
                raise RequestValidationError("content_type")
            raw_length = self.headers.get("content-length")
            if raw_length is None:
                raise RequestValidationError("content_length")
            try:
                declared_length = int(raw_length)
            except ValueError as error:
                raise RequestValidationError("content_length") from error
            self._request_size_bucket = _request_size_bucket(declared_length)
            if declared_length <= 0:
                raise RequestValidationError("content_length")
            if declared_length > MAX_BODY_BYTES:
                self.reply(413, error_response("INVALID_REQUEST"))
                return
            workout = parse_workout_request(self.rfile.read(declared_length))
            deadline = self._started_at + TOTAL_REQUEST_BUDGET_SECONDS
            feedback = generate_feedback(workout, deadline)
            self.reply(200, feedback_response(feedback))
        except RequestValidationError:
            self.reply(400, error_response("INVALID_REQUEST"))
        except ProviderConfigurationError:
            self._provider_status_class = "configuration"
            self.reply(503, error_response("AI_UNAVAILABLE"))
        except ProviderTimeoutError:
            self._provider_status_class = "timeout"
            self.reply(504, error_response("AI_TIMEOUT"))
        except ProviderUnavailableError as error:
            self._provider_status_class = error.status_class
            self.reply(503, error_response("AI_UNAVAILABLE"))
        except ProviderResponseInvalidError:
            self._provider_status_class = "invalid_response"
            self.reply(502, error_response("AI_RESPONSE_INVALID"))
        except Exception:
            self.reply(500, error_response("SERVER_ERROR"))

    do_PUT = _invalid_method
    do_PATCH = _invalid_method
    do_DELETE = _invalid_method
    do_OPTIONS = _invalid_method
    do_HEAD = _invalid_method

    def log_request(self, code: int | str = "-", size: int | str = "-") -> None:
        pass

    def log_message(self, fmt: str, *args: object) -> None:
        pass


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8787"))
    host = os.getenv("BIND_HOST", "127.0.0.1")
    print(f"Workout AI backend: http://{host}:{port}")
    ThreadingHTTPServer((host, port), Handler).serve_forever()
