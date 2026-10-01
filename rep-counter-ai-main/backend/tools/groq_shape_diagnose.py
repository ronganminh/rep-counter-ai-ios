#!/usr/bin/env python3
"""Read-only Groq access/response diagnostic using synthetic data only."""
from __future__ import annotations

import http.client
import json
from pathlib import Path

ENV_PATH = Path("/home/nduythanh/apps/repcoach-backend/.env")
TARGET_MODEL = "openai/gpt-oss-20b"


def load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in ENV_PATH.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def request_json(
    method: str,
    path: str,
    key: str,
    *,
    payload: dict | None = None,
) -> tuple[int, bytes]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"authorization": "Bearer " + key}
    if body is not None:
        headers["content-type"] = "application/json"

    conn = http.client.HTTPSConnection("api.groq.com", timeout=20)
    try:
        conn.request(method, path, body=body, headers=headers)
        response = conn.getresponse()
        return response.status, response.read()
    finally:
        conn.close()


def main() -> None:
    env = load_env()
    key = env.get("GROQ_API_KEY", "")
    model = env.get("GROQ_MODEL", TARGET_MODEL)
    if not key:
        print("GROQ_API_KEY=MISSING")
        return

    try:
        status, raw = request_json("GET", "/openai/v1/models", key)
    except Exception as error:
        print(f"MODELS_NETWORK_ERROR={type(error).__name__}")
        return

    print(f"MODELS_STATUS={status}")
    model_visible = False
    if 200 <= status < 300:
        try:
            data = json.loads(raw.decode("utf-8"))
            models = data.get("data")
            if isinstance(models, list):
                model_visible = any(
                    isinstance(item, dict) and item.get("id") == model
                    for item in models
                )
        except Exception:
            pass
    print(f"TARGET_MODEL_VISIBLE={'YES' if model_visible else 'NO'}")

    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": (
                    "Return two short English sentences of general workout "
                    "feedback for a synthetic push-up set: 20 reps, 2 sets, "
                    "quality score 88. No medical advice."
                ),
            }
        ],
        "temperature": 0.6,
        "max_completion_tokens": 512,
        "reasoning_effort": "low",
        "include_reasoning": False,
    }

    try:
        status, raw = request_json(
            "POST",
            "/openai/v1/chat/completions",
            key,
            payload=payload,
        )
    except Exception as error:
        print(f"CHAT_NETWORK_ERROR={type(error).__name__}")
        return

    print(f"CHAT_STATUS={status}")
    print(f"CHAT_BYTES={len(raw)}")
    if not 200 <= status < 300:
        return

    try:
        data = json.loads(raw.decode("utf-8"))
    except Exception as error:
        print(f"CHAT_JSON_PARSE=FAIL:{type(error).__name__}")
        return

    choices = data.get("choices")
    print(f"CHOICES_TYPE={type(choices).__name__}")
    print(f"CHOICES_LEN={len(choices) if isinstance(choices, list) else -1}")
    if isinstance(choices, list) and choices and isinstance(choices[0], dict):
        choice = choices[0]
        print(f"FINISH_REASON={choice.get('finish_reason')}")
        message = choice.get("message")
        print(f"MESSAGE_TYPE={type(message).__name__}")
        if isinstance(message, dict):
            content = message.get("content")
            reasoning = message.get("reasoning")
            print(f"CONTENT_TYPE={type(content).__name__}")
            print(f"CONTENT_LEN={len(content) if isinstance(content, str) else -1}")
            print(f"REASONING_TYPE={type(reasoning).__name__}")
            print(f"REASONING_LEN={len(reasoning) if isinstance(reasoning, str) else -1}")


if __name__ == "__main__":
    main()
