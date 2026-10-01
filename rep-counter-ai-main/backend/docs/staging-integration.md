# B6 staging integration contract

Date: 2026-10-01

This document records the exact Flutter to backend contract proved by the B6 synthetic staging harness. It does not authorize production deployment.

## Flutter request

AiFeedbackService sends POST /v1/workout-feedback with Content-Type application/json and a 25 second client timeout.

The shipped client now sends request schema v2:

    schema_version = 2
    consent_version = LegalConfig.aiConsentVersion = 2026-10-01-groq

The aggregate workout fields are defined by WorkoutRecord.toAiPayload(). Contract metadata is added by AiFeedbackService, not stored in the workout model.

The shared synthetic contract fixture is:

    rep-counter-ai-main/contracts/workout_feedback_v2.json

It contains only non-personal aggregate test data.

## Backend request compatibility

The backend continues to accept:

    legacy request without schema_version -> normalized to v1
    schema_version = 1
    schema_version = 2 + consent_version

B6 does not remove v1. Removing v1 requires a later separately reviewed change after the v2 app has shipped and been observed.

## Success response

Flutter requires response schema_version 1 and a non-empty feedback string. Unknown or future response schema versions fail closed as a server-contract error instead of being silently accepted.

## Stable failures consumed by Flutter

    transport ClientException -> offline
    client 25 s timeout      -> timeout
    AI_TIMEOUT               -> timeout
    AI_UNAVAILABLE           -> server/retry UI
    AI_RESPONSE_INVALID      -> server/retry UI
    RATE_LIMITED             -> server/retry UI
    other non-200            -> server/retry UI
    malformed success body   -> server/retry UI

Timeout layering remains:

    backend total budget 20 s
    Nginx read timeout   22 s
    Flutter timeout      25 s

## Consent behavior proved

Focused Flutter tests verify:

    manual consent Cancel -> zero AI requests
    manual consent Agree  -> exactly one request

Automatic consent remains versioned and opt-in from B4.

## Local-first failure behavior proved

Focused controller/widget tests verify:

    backend offline -> workout record survives; no feedback save
    timeout         -> workout survives; retry/error UI remains available
    success         -> feedback is attached and saved locally once

The existing full Flutter test suite remains the regression guard for non-AI local-first product behavior.

## Synthetic staging harness

B6 adds a CI-only staging harness at backend/tools/fake_staging_server.py.

It runs the real Python server.Handler and replaces only the provider call with deterministic synthetic feedback. It never calls Groq or Gemini and requires no provider secret.

The Flutter-side smoke client at rep_counter_app/tool/staging_contract_smoke.dart checks over real HTTP:

    GET /health
    GET /ready
    POST /v1/workout-feedback using the shared v2 fixture
    response schema v1
    X-Request-ID

GitHub Actions workflow .github/workflows/staging-integration-ci.yml runs this cross-stack smoke plus the focused Flutter integration tests.

## External staging

No dedicated remote staging hostname is defined in the repository. The smoke client accepts STAGING_BASE_URL so an operator can run the same synthetic request against an external staging deployment later.

Do not use the production hostname merely to satisfy B6. Production provider selection is now GroqCloud; B7 still requires VPS deployment, provider-config preflight and public smoke checks.
