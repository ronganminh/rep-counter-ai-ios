# RepCoach production deployment guide

This document reflects the post-B7 production state as of 2026-10-01.

The authoritative backend deployment and rollback procedure is:

    ../backend/docs/production-release.md

Use that runbook for App Store backend readiness, Groq provider preflight, Nginx/systemd deployment, production smoke testing and rollback.

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

Nginx proxies the public route to the backend, and the backend serves the canonical file at:

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

Earlier versions of this guide described a separate legacy web-root directory as the source of the public privacy page and listed a static-site rsync workflow. That procedure is obsolete for the B4+ Privacy Policy.

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

Current production provider configuration is:

    AI_PROVIDER=groq
    GROQ_MODEL=openai/gpt-oss-20b
    GROQ_API_KEY=<server secret>

The Groq API key stays only in the production VPS environment file. Read-only production checks verify that the key is present without printing it. Privileged deployment remains manual because the VPS requires interactive sudo. Provider data/terms notes are recorded in backend/docs/groq-provider.md. Core workouts remain local-first if the optional AI provider is unavailable.

## Store URLs

The in-app Privacy Policy URL is:

    https://repcoach-ai.duckdns.org/privacy-policy.html

Any separate marketing/support/terms pages under docs/ are outside the B7 backend deployment contract unless a reviewed Nginx route explicitly serves them.

Do not advertise an external store URL that has not been smoke-tested from the public internet.


## Production verification workflows

Manual read-only VPS verification:

    .github/workflows/production-ops-check.yml

Manual synthetic live production smoke:

    .github/workflows/production-readiness.yml

The first workflow does not use sudo, restart services or call Groq directly. The second runs the reviewed synthetic production smoke and therefore exercises the public AI route.
