"""Swappable AI provider boundary for RepCoach workout feedback."""
from __future__ import annotations

import http.client
import json
import os
import socket
import time
from typing import Callable, Protocol


MAX_PROVIDER_RESPONSE_BYTES = 65_536
MAX_FEEDBACK_CHARS = 2_000
PROVIDER_CONNECT_TIMEOUT_SECONDS = 5
PROVIDER_RESPONSE_TIMEOUT_SECONDS = 15
SUPPORTED_GEMINI_SERVICE_MODES = {"billing_enabled"}
# RepCoach production privacy contract: never send workout summaries through
# Gemini Unpaid Services. The exact Google project must still be verified in
# AI Studio before GEMINI_SERVICE_MODE=billing_enabled is configured.

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


class AiProvider(Protocol):
    """Provider contract consumed by the RepCoach HTTP layer."""

    def generate_feedback(self, request: dict, *, deadline: float) -> str:
        ...


class ProviderConfigurationError(Exception):
    """Provider configuration is missing, unsupported, or unverified."""


class ProviderTimeoutError(Exception):
    """The provider exceeded the configured connect/response/total budget."""


class ProviderUnavailableError(Exception):
    """The provider could not service the request."""

    def __init__(self, status_class: str = "network") -> None:
        super().__init__(status_class)
        self.status_class = status_class


class ProviderResponseInvalidError(Exception):
    """The provider returned a response that cannot be safely consumed."""


def prompt_summary(workout: dict) -> dict:
    """Return only the minimized workout fields permitted in the model prompt."""
    return {key: workout[key] for key in PROMPT_FIELDS if key in workout}


def validate_feedback_text(feedback: object) -> str:
    if not isinstance(feedback, str):
        raise ProviderResponseInvalidError()
    cleaned = feedback.strip()
    if not cleaned or len(cleaned) > MAX_FEEDBACK_CHARS:
        raise ProviderResponseInvalidError()
    return cleaned


def parse_provider_response(raw: bytes) -> str:
    if len(raw) > MAX_PROVIDER_RESPONSE_BYTES:
        raise ProviderResponseInvalidError()
    try:
        result = json.loads(raw.decode("utf-8"))
        feedback = result["candidates"][0]["content"]["parts"][0]["text"]
    except (UnicodeDecodeError, json.JSONDecodeError, KeyError, IndexError, TypeError) as error:
        raise ProviderResponseInvalidError() from error
    return validate_feedback_text(feedback)


def _remaining_seconds(deadline: float, cap: int) -> float:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise ProviderTimeoutError()
    return min(float(cap), remaining)


class GeminiProvider:
    """Gemini Developer API implementation behind the AiProvider boundary."""

    name = "gemini"

    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        service_mode: str,
        connection_factory: Callable[..., http.client.HTTPSConnection] = http.client.HTTPSConnection,
    ) -> None:
        if not api_key.strip():
            raise ProviderConfigurationError()
        if not model.strip():
            raise ProviderConfigurationError()
        if service_mode not in SUPPORTED_GEMINI_SERVICE_MODES:
            raise ProviderConfigurationError()
        self._api_key = api_key.strip()
        self.model = model.strip()
        self.service_mode = service_mode
        self._connection_factory = connection_factory

    def generate_feedback(self, request: dict, *, deadline: float) -> str:
        locale = request["locale"]
        prompt = PROMPTS[locale] + json.dumps(prompt_summary(request), ensure_ascii=False)
        provider_payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.4, "maxOutputTokens": 220},
        }
        body = json.dumps(provider_payload).encode("utf-8")
        path = f"/v1beta/models/{self.model}:generateContent"
        connection = self._connection_factory(
            "generativelanguage.googleapis.com",
            timeout=_remaining_seconds(deadline, PROVIDER_CONNECT_TIMEOUT_SECONDS),
        )
        try:
            connection.connect()
            if connection.sock is not None:
                connection.sock.settimeout(
                    _remaining_seconds(deadline, PROVIDER_RESPONSE_TIMEOUT_SECONDS)
                )
            connection.request(
                "POST",
                path,
                body=body,
                headers={
                    "content-type": "application/json",
                    "x-goog-api-key": self._api_key,
                },
            )
            response = connection.getresponse()
            if response.status < 200 or response.status >= 300:
                raise ProviderUnavailableError(f"{response.status // 100}xx")
            raw = response.read(MAX_PROVIDER_RESPONSE_BYTES + 1)
            if time.monotonic() > deadline:
                raise ProviderTimeoutError()
            return parse_provider_response(raw)
        except (TimeoutError, socket.timeout) as error:
            raise ProviderTimeoutError() from error
        except (
            ProviderUnavailableError,
            ProviderTimeoutError,
            ProviderResponseInvalidError,
        ):
            raise
        except (OSError, http.client.HTTPException) as error:
            raise ProviderUnavailableError("network") from error
        finally:
            connection.close()


def build_provider_from_env() -> AiProvider:
    """Build a provider only from explicit, source-independent deployment metadata."""
    provider_name = os.getenv("AI_PROVIDER", "gemini").strip().lower()
    if provider_name != "gemini":
        raise ProviderConfigurationError()

    return GeminiProvider(
        api_key=os.getenv("GEMINI_API_KEY", ""),
        model=os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite"),
        service_mode=os.getenv("GEMINI_SERVICE_MODE", "").strip().lower(),
    )
