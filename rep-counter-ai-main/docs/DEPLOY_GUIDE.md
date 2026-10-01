# RepCoach production deployment guide

This document was refreshed for Track B phase B7 on 2026-10-01.

The authoritative backend deployment and rollback procedure is:

    ../backend/docs/production-release.md

Use that runbook for App Store backend readiness, provider/billing gates, Nginx/systemd deployment, production smoke testing and rollback.

## Canonical production origin

    https://repcoach-ai.duckdns.org

Public backend routes:

    GET  /health
    GET  /ready
    POST /v1/workout-feedback
    GET  /privacy-policy.html

## Canonical Privacy Policy source

The production Privacy Policy is no longer deployed from docs/privacy-policy.html.

Canonical source:

    ../backend/static/privacy-policy.html

Nginx serves that file directly at:

    https://repcoach-ai.duckdns.org/privacy-policy.html

The legacy docs/privacy-policy.html file exists only as a redirect/pointer and must not be treated as the deployed policy source.

## Backend layout

Application directory:

    /home/nduythanh/apps/repcoach-backend

Systemd:

    /etc/systemd/system/repcoach-backend.service

Nginx site:

    /etc/nginx/sites-available/repcoach-ai

Rate-limit/log format:

    /etc/nginx/conf.d/repcoach-rate-limit.conf

Log rotation:

    /etc/logrotate.d/repcoach-ai

Provider environment:

    /home/nduythanh/apps/repcoach-backend/.env

Never commit or copy the production .env into the repository.

## Do not use the old static-site deployment procedure

Earlier versions of this guide described /var/www/repcoach-ai as the source of the public privacy page and listed a separate static-site rsync workflow. That procedure is obsolete for the B4+ Privacy Policy.

Do not overwrite the Nginx site with an older configuration from a previous release. Doing so can remove:

- request/body limits;
- rate limiting;
- stable JSON errors;
- request IDs;
- /ready;
- bounded proxy timeouts;
- privacy-policy routing;
- privacy-safe access logging.

Deploy from the reviewed release commit and validate with sudo nginx -t before reload.

## Release smoke

After deployment run:

    cd rep-counter-ai-main/backend
    python3 tools/production_smoke.py

The script sends only the shared synthetic v2 fixture. It checks TLS, HTTP to HTTPS redirect, health/readiness, the canonical Privacy Policy, method/body guards, response schema, request ID and latency.

Then use the returned request ID to verify safe logs on the VPS as documented in backend/docs/production-release.md.

## Provider gate

Production AI must not be enabled merely because GEMINI_SERVICE_MODE says billing_enabled.

An admin must independently verify the exact production project is on a Paid Tier in Google AI Studio and confirm the current provider terms fit the intended product audience/use case. If that cannot be established, leave AI unavailable; core workouts remain local-first.

## Store URLs

The in-app Privacy Policy URL is:

    https://repcoach-ai.duckdns.org/privacy-policy.html

Any separate marketing/support/terms pages under docs/ are outside the B7 backend deployment contract unless a reviewed Nginx route explicitly serves them.

Do not advertise an external store URL that has not been smoke-tested from the public internet.
