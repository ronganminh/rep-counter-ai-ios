#!/usr/bin/env python3
"""Synthetic production smoke checks for the RepCoach public backend.

This script never reads a provider API key. It sends only the shared synthetic
workout fixture and validates public behavior expected after a B7 deployment.
"""
from __future__ import annotations

import argparse
import http.client
import json
import re
import ssl
import sys
import time
from pathlib import Path
from urllib.parse import urlparse


REQUEST_ID_RE = re.compile(r"^[0-9a-f]{32}$")
FORBIDDEN_PUBLIC_MARKERS = (
    "GEMINI_API_KEY",
    "x-goog-api-key",
    "generativelanguage.googleapis.com",
    "Traceback",
    '"detail"',
)


class SmokeFailure(RuntimeError):
    pass


def _assert(condition: bool, message: str) -> None:
    if not condition:
        raise SmokeFailure(message)


def _headers(response: http.client.HTTPResponse) -> dict[str, str]:
    return {key.lower(): value for key, value in response.getheaders()}


def _decode_json(raw: bytes) -> dict:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SmokeFailure("response was not valid UTF-8 JSON") from error
    _assert(isinstance(value, dict), "JSON response root was not an object")
    return value


def _scan_for_secret_leak(raw: bytes, headers: dict[str, str]) -> None:
    text = raw.decode("utf-8", errors="replace")
    combined = text + "\n" + "\n".join(f"{k}: {v}" for k, v in headers.items())
    for marker in FORBIDDEN_PUBLIC_MARKERS:
        _assert(marker not in combined, f"public response leaked forbidden marker: {marker}")


def _request(
    host: str,
    port: int,
    method: str,
    path: str,
    *,
    body: bytes | None = None,
    headers: dict[str, str] | None = None,
    timeout: float = 30.0,
) -> tuple[int, dict[str, str], bytes, float]:
    started = time.monotonic()
    conn = http.client.HTTPSConnection(
        host,
        port=port,
        timeout=timeout,
        context=ssl.create_default_context(),
    )
    try:
        conn.request(method, path, body=body, headers=headers or {})
        response = conn.getresponse()
        raw = response.read()
        elapsed = time.monotonic() - started
        return response.status, _headers(response), raw, elapsed
    finally:
        conn.close()


def _check_https_headers(headers: dict[str, str]) -> None:
    _assert("strict-transport-security" in headers, "missing HSTS header")
    _assert(
        headers.get("x-content-type-options", "").lower() == "nosniff",
        "missing X-Content-Type-Options: nosniff",
    )
    _assert("no-store" in headers.get("cache-control", "").lower(), "missing no-store")


def _check_request_id(headers: dict[str, str]) -> str:
    value = headers.get("x-request-id", "")
    _assert(bool(REQUEST_ID_RE.fullmatch(value)), "missing/invalid X-Request-ID")
    return value


def check_http_redirect(host: str) -> None:
    conn = http.client.HTTPConnection(host, port=80, timeout=10)
    try:
        conn.request("GET", "/health")
        response = conn.getresponse()
        response.read()
        headers = _headers(response)
    finally:
        conn.close()
    _assert(response.status in (301, 308), f"HTTP redirect status was {response.status}")
    location = headers.get("location", "")
    _assert(location.startswith(f"https://{host}/"), f"unexpected redirect Location: {location}")
    print(f"PASS http_redirect status={response.status}")


def check_tls(host: str, port: int) -> None:
    context = ssl.create_default_context()
    with context.wrap_socket(
        __import__("socket").create_connection((host, port), timeout=10),
        server_hostname=host,
    ) as sock:
        cert = sock.getpeercert()
        ssl.match_hostname(cert, host)
        not_after = cert.get("notAfter")
    _assert(bool(not_after), "TLS certificate had no notAfter")
    print(f"PASS tls hostname={host} expires={not_after}")


def check_health(host: str, port: int) -> None:
    status, headers, raw, elapsed = _request(host, port, "GET", "/health", timeout=10)
    _scan_for_secret_leak(raw, headers)
    _assert(status == 200, f"/health returned {status}: {raw[:300]!r}")
    _assert(_decode_json(raw) == {"status": "ok"}, f"unexpected /health body: {raw!r}")
    _check_https_headers(headers)
    request_id = _check_request_id(headers)
    print(f"PASS health latency_ms={round(elapsed * 1000)} request_id={request_id}")


def check_ready(host: str, port: int) -> None:
    status, headers, raw, elapsed = _request(host, port, "GET", "/ready", timeout=10)
    _scan_for_secret_leak(raw, headers)
    _assert(status == 200, f"/ready returned {status}: {raw[:300]!r}")
    _assert(_decode_json(raw) == {"status": "ready"}, f"unexpected /ready body: {raw!r}")
    _check_https_headers(headers)
    request_id = _check_request_id(headers)
    print(f"PASS ready latency_ms={round(elapsed * 1000)} request_id={request_id}")


def check_privacy(host: str, port: int) -> None:
    status, headers, raw, elapsed = _request(
        host, port, "GET", "/privacy-policy.html", timeout=10
    )
    _assert(status == 200, f"privacy policy returned {status}")
    content_type = headers.get("content-type", "").lower()
    _assert("text/html" in content_type, f"privacy policy content-type was {content_type}")
    text = raw.decode("utf-8")
    for marker in (
        "RepCoach AI",
        "October 1, 2026",
        "2026-10-01",
        'id="en"',
        'id="vi"',
    ):
        _assert(marker in text, f"privacy policy missing marker: {marker}")
    _check_https_headers(headers)
    print(f"PASS privacy latency_ms={round(elapsed * 1000)} bytes={len(raw)}")


def check_method_guard(host: str, port: int) -> None:
    status, headers, raw, _ = _request(host, port, "GET", "/v1/workout-feedback", timeout=10)
    _scan_for_secret_leak(raw, headers)
    _assert(status == 405, f"GET feedback route returned {status}")
    _assert(_decode_json(raw) == {"error": "INVALID_REQUEST"}, "unexpected 405 body")
    _assert(headers.get("allow") == "POST", "405 response missing Allow: POST")
    _check_request_id(headers)
    print("PASS method_guard")


def check_body_limit(host: str, port: int) -> None:
    body = b'{"pad":"' + (b"x" * 17_000) + b'"}'
    status, headers, raw, _ = _request(
        host,
        port,
        "POST",
        "/v1/workout-feedback",
        body=body,
        headers={"content-type": "application/json"},
        timeout=10,
    )
    _scan_for_secret_leak(raw, headers)
    _assert(status == 413, f"oversized body returned {status}: {raw[:300]!r}")
    _assert(_decode_json(raw) == {"error": "INVALID_REQUEST"}, "unexpected 413 body")
    _check_request_id(headers)
    print("PASS body_limit")


def check_feedback(host: str, port: int, fixture_path: Path) -> str:
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
    _assert(fixture.get("schema_version") == 2, "fixture must use schema v2")
    _assert(fixture.get("consent_version") == "2026-10-01", "fixture consent version drift")
    body = json.dumps(fixture, separators=(",", ":")).encode("utf-8")
    status, headers, raw, elapsed = _request(
        host,
        port,
        "POST",
        "/v1/workout-feedback",
        body=body,
        headers={"content-type": "application/json"},
        timeout=27,
    )
    _scan_for_secret_leak(raw, headers)
    _assert(status == 200, f"feedback returned {status}: {raw[:500]!r}")
    decoded = _decode_json(raw)
    _assert(decoded.get("schema_version") == 1, "unexpected response schema_version")
    feedback = decoded.get("feedback")
    _assert(isinstance(feedback, str) and feedback.strip(), "feedback was empty")
    _assert(len(feedback) <= 2_000, "feedback exceeded 2,000 chars")
    _assert(elapsed < 25, f"feedback latency {elapsed:.2f}s exceeded Flutter budget")
    _check_https_headers(headers)
    request_id = _check_request_id(headers)
    print(
        "PASS feedback "
        f"latency_ms={round(elapsed * 1000)} "
        f"feedback_chars={len(feedback)} request_id={request_id}"
    )
    return request_id


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--base-url",
        default="https://repcoach-ai.duckdns.org",
        help="Production base URL; HTTPS is required.",
    )
    parser.add_argument(
        "--fixture",
        default=str(Path(__file__).resolve().parents[2] / "contracts" / "workout_feedback_v2.json"),
    )
    args = parser.parse_args()

    parsed = urlparse(args.base_url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise SmokeFailure("--base-url must be a valid HTTPS origin")
    if parsed.path not in ("", "/"):
        raise SmokeFailure("--base-url must not contain a path")

    host = parsed.hostname
    port = parsed.port or 443
    fixture_path = Path(args.fixture)
    _assert(fixture_path.is_file(), f"fixture not found: {fixture_path}")

    print(f"RepCoach production smoke: https://{host}:{port}")
    check_http_redirect(host)
    check_tls(host, port)
    check_health(host, port)
    check_ready(host, port)
    check_privacy(host, port)
    check_method_guard(host, port)
    check_body_limit(host, port)
    request_id = check_feedback(host, port, fixture_path)
    print(f"PRODUCTION_SMOKE_PASS feedback_request_id={request_id}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SmokeFailure as error:
        print(f"PRODUCTION_SMOKE_FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
