#!/usr/bin/env python3
"""Read-only Groq response-shape diagnostic using synthetic data only."""
from __future__ import annotations

import json
import urllib.error
import urllib.request
from pathlib import Path

ENV_PATH = Path("/home/nduythanh/apps/repcoach-backend/.env")


def load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in ENV_PATH.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def main() -> None:
    env = load_env()
    key = env.get("GROQ_API_KEY", "")
    model = env.get("GROQ_MODEL", "openai/gpt-oss-20b")
    if not key:
        print("GROQ_API_KEY=MISSING")
        return

    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "Return two short English sentences of general workout "
                    "feedback. No medical advice."
                ),
            },
            {
                "role": "user",
                "content": json.dumps(
                    {
                        "exercise": "push_up",
                        "duration_seconds": 120,
                        "reps": 20,
                        "sets": 2,
                        "quality_score": 88,
                        "has_enough_data": True,
                    }
                ),
            },
        ],
        "temperature": 0.4,
        "max_tokens": 220,
    }
    request = urllib.request.Request(
        "https://api.groq.com/openai/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = response.read()
            status = response.status
    except urllib.error.HTTPError as error:
        raw = error.read()
        status = error.code
    except Exception as error:
        print(f"GROQ_NETWORK_ERROR={type(error).__name__}")
        return

    print(f"GROQ_STATUS={status}")
    print(f"RAW_BYTES={len(raw)}")
    try:
        data = json.loads(raw.decode("utf-8"))
    except Exception as error:
        print(f"JSON_PARSE=FAIL:{type(error).__name__}")
        return

    print("TOP_KEYS=" + ",".join(sorted(data.keys())))
    choices = data.get("choices")
    print(f"CHOICES_TYPE={type(choices).__name__}")
    print(f"CHOICES_LEN={len(choices) if isinstance(choices, list) else -1}")

    if isinstance(choices, list) and choices:
        choice = choices[0]
        if isinstance(choice, dict):
            print("CHOICE_KEYS=" + ",".join(sorted(choice.keys())))
            print(f"FINISH_REASON={choice.get('finish_reason')}")
            message = choice.get("message")
            print(f"MESSAGE_TYPE={type(message).__name__}")
            if isinstance(message, dict):
                print("MESSAGE_KEYS=" + ",".join(sorted(message.keys())))
                content = message.get("content")
                reasoning = message.get("reasoning")
                print(f"CONTENT_TYPE={type(content).__name__}")
                print(f"CONTENT_LEN={len(content) if isinstance(content, str) else -1}")
                print(f"REASONING_TYPE={type(reasoning).__name__}")
                print(
                    f"REASONING_LEN={len(reasoning) if isinstance(reasoning, str) else -1}"
                )

    error = data.get("error")
    if isinstance(error, dict):
        print(f"ERROR_TYPE={error.get('type')}")
        print(f"ERROR_CODE={error.get('code')}")


if __name__ == "__main__":
    main()
