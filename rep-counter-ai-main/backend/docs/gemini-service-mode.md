# Legacy Gemini provider record — not production

Status date: **2026-10-01**

RepCoach production does **not** currently use Gemini. Production uses GroqCloud; see:

    docs/groq-provider.md
    docs/production-release.md

The Gemini adapter remains in source only as a legacy/optional provider seam.

## What this file means

This file is historical implementation context, not a current production-release gate.

If RepCoach intentionally switches production back to Gemini in the future, do not rely on the 2026-10-01 assumptions recorded during the original Gemini work. Before enabling Gemini again:

1. verify the exact current Gemini API terms and supported deployment mode;
2. verify the actual Google project/billing/service state outside source code;
3. review audience/use restrictions applicable at that time;
4. review prompt/response retention and data-use terms;
5. review whether the intended workout-summary data is appropriate;
6. update the public Privacy Policy and in-app consent wording;
7. bump the consent version if the provider/data-processing change is material;
8. run provider tests, staging integration and production smoke before release.

## Legacy adapter configuration

The current source retains support for:

    AI_PROVIDER=gemini
    GEMINI_API_KEY=<server secret>
    GEMINI_MODEL=<model>
    GEMINI_SERVICE_MODE=billing_enabled

The service-mode environment value is a guard/configuration assertion only; it is not proof of an external project's billing or legal status.

## Data minimization remains mandatory

If Gemini is ever re-enabled, continue to exclude:

- identity/account data;
- routine libraries;
- full workout history;
- PR/streak/badge history;
- camera images/video;
- audio;
- raw pose landmarks;
- per-rep raw detail.

Only a separately reviewed aggregate workout summary may cross the provider boundary.

## Production truth

Current production truth is defined by the Groq provider record and the deployed Privacy Policy. Nothing in this legacy file should be interpreted as a current Gemini production blocker or current Gemini deployment approval.
