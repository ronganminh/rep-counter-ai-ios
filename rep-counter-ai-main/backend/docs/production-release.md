# B7 production release runbook

Status date: **2026-10-01**

This runbook prepares the RepCoach backend for App Store review traffic. It does not treat source code, an API key, or a successful request as proof that the Google project is on a paid billing tier.

## Current release status

| Gate | Status | Evidence / action |
| --- | --- | --- |
| B1-B6 merged to main | PASS | API contract, security, provider adapter, privacy, observability and staging integration are on main |
| Backend CI | PASS | B6 backend suite passed before merge |
| Flutter integration | PASS | B6 staging + full Flutter suite passed before merge |
| Exact production Gemini project verified Paid Tier | **BLOCKED / admin action required** | Check the exact project in Google AI Studio Projects/Billing |
| Gemini audience/use-case terms fit | **BLOCKED / product-legal decision required** | Current Gemini Additional Terms require users to be 18+ and state Gemini API is for professional/business purposes, not consumer use |
| Production VPS updated to B7 source/config | **FAIL / NOT DEPLOYED** | Public smoke shows the live host still exposes the pre-B5 health/API behavior |
| Public production smoke after deploy | **FAIL (pre-deploy baseline)** | GitHub Actions run 36816755738 proves current live drift; rerun after deployment |
| Safe production log sample checked by request ID | **NOT VERIFIED** | Requires SSH/admin access to journal/Nginx logs |

Do not mark production ready until every blocking item is resolved.

## Observed live production baseline before B7 deploy

Public synthetic smoke from GitHub Actions on 2026-10-01 (run 36816755738) reached the real production hostname and found:

- HTTP to HTTPS redirect: PASS (301).
- TLS hostname validation: PASS.
- certificate expiry observed by the smoke: 2026-12-06 06:21:29 GMT.
- GET /health: FAIL for B7 contract; live body is the older `{"ok": true, "service": "repcoach-ai"}`.
- GET /ready: FAIL; live route returns 404.
- GET /privacy-policy.html: reachable, but FAIL for the B4 policy markers/effective date.
- GET /v1/workout-feedback: FAIL; live Nginx returns 403 instead of the stable JSON 405 contract.
- oversized POST: FAIL; live response is not the stable JSON 413 contract.
- synthetic v2 feedback POST: the endpoint responds, but FAIL because the response lacks the required response `schema_version`.

This evidence means the public host is still on an older backend/Nginx/privacy deployment. Do not interpret the working TLS or provider response as B7 readiness or as proof of Paid Tier.

Official provider sources to re-check at release time:

- https://ai.google.dev/gemini-api/terms
- https://ai.google.dev/gemini-api/docs/billing
- https://ai.google.dev/gemini-api/docs/zdr

## Production topology

Public origin:

    https://repcoach-ai.duckdns.org

Process:

    nginx :443
      -> 127.0.0.1:8787
      -> repcoach-backend.service
      -> Python server.py
      -> AiProvider / GeminiProvider

The backend intentionally has no user-account database and no workout-history database. Do not introduce a cloud workout database as part of deployment.

## Process management

Service name:

    repcoach-backend

Systemd unit:

    /etc/systemd/system/repcoach-backend.service

Application working directory:

    /home/nduythanh/apps/repcoach-backend

Environment source:

    /home/nduythanh/apps/repcoach-backend/.env

The .env file is a server secret and must never be copied into Git, CI artifacts, screenshots, tickets, or release notes.

Restart:

    sudo systemctl restart repcoach-backend

Status:

    sudo systemctl status repcoach-backend --no-pager

Application metadata logs:

    sudo journalctl -u repcoach-backend -n 100 --no-pager

Nginx logs:

    /var/log/nginx/repcoach-ai.access.log
    /var/log/nginx/repcoach-ai.error.log

The dedicated Nginx logs rotate daily and keep the current log plus 14 rotations under deploy/repcoach-ai.logrotate. System journal retention is controlled by the VPS journal configuration; do not claim a fixed journal duration unless the host configuration is separately verified.

## Provider / billing release gate

Before changing production files, an admin who can access the exact Google project used by the production API key must:

1. Open Google AI Studio.
2. Locate the exact project associated with the production API key.
3. Verify its Billing Tier/Plan is a Paid Tier.
4. Record the project name/identifier, observed tier, checker and timestamp in a private release record.
5. Re-check the current Gemini API Additional Terms.
6. Confirm the product/distribution plan satisfies the then-current audience/use restrictions.

Do not put the project identifier, billing account ID, API key, payment data or screenshots containing secrets in this public repository.

The server-side .env must include:

    AI_PROVIDER=gemini
    GEMINI_API_KEY=<server secret>
    GEMINI_MODEL=<approved model>
    GEMINI_SERVICE_MODE=billing_enabled
    PORT=8787
    BIND_HOST=127.0.0.1

The code rejects missing, unpaid or unknown service modes, but that guard is not proof of the Google project's actual billing state.

Safe local configuration check on the VPS (prints no secret values):

    cd /home/nduythanh/apps/repcoach-backend
    set -a
    . ./.env
    set +a
    test "$AI_PROVIDER" = "gemini"
    test -n "$GEMINI_API_KEY"
    test "$GEMINI_SERVICE_MODE" = "billing_enabled"
    test "$BIND_HOST" = "127.0.0.1"

## Files deployed from the repository

Application:

    backend/server.py
    backend/ai_provider.py
    backend/static/privacy-policy.html

System configuration:

    backend/deploy/repcoach-backend.service
    backend/deploy/repcoach-ai.nginx
    backend/deploy/repcoach-rate-limit.conf
    backend/deploy/repcoach-ai.logrotate

Do not replace the production .env from the repository.

## Pre-deploy backup

Create a root-only backup of the files that B7 changes. The .env is deliberately not copied because deployment does not replace it.

Example:

    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    backup="/var/backups/repcoach-b7/$stamp"

    sudo install -d -m 0700 "$backup/app" "$backup/system"

    sudo cp -a /home/nduythanh/apps/repcoach-backend/server.py "$backup/app/server.py" 2>/dev/null || true
    sudo cp -a /home/nduythanh/apps/repcoach-backend/ai_provider.py "$backup/app/ai_provider.py" 2>/dev/null || true
    sudo cp -a /home/nduythanh/apps/repcoach-backend/static "$backup/app/static" 2>/dev/null || true

    sudo cp -a /etc/systemd/system/repcoach-backend.service "$backup/system/repcoach-backend.service" 2>/dev/null || true
    sudo cp -a /etc/nginx/sites-available/repcoach-ai "$backup/system/nginx-site" 2>/dev/null || true
    sudo cp -a /etc/nginx/conf.d/repcoach-rate-limit.conf "$backup/system/rate-limit.conf" 2>/dev/null || true
    sudo cp -a /etc/logrotate.d/repcoach-ai "$backup/system/logrotate" 2>/dev/null || true

Record only the backup path in the private release record.

## Deploy

From a checked-out copy of the release commit on the VPS, with the repository root as the current directory:

    src="rep-counter-ai-main/backend"
    app="/home/nduythanh/apps/repcoach-backend"

    install -d -m 0755 "$app/static"
    install -m 0644 "$src/server.py" "$app/server.py"
    install -m 0644 "$src/ai_provider.py" "$app/ai_provider.py"
    install -m 0644 "$src/static/privacy-policy.html" "$app/static/privacy-policy.html"

    sudo install -m 0644 "$src/deploy/repcoach-backend.service" /etc/systemd/system/repcoach-backend.service
    sudo install -m 0644 "$src/deploy/repcoach-ai.nginx" /etc/nginx/sites-available/repcoach-ai
    sudo install -m 0644 "$src/deploy/repcoach-rate-limit.conf" /etc/nginx/conf.d/repcoach-rate-limit.conf
    sudo install -m 0644 "$src/deploy/repcoach-ai.logrotate" /etc/logrotate.d/repcoach-ai

    sudo systemctl daemon-reload
    sudo nginx -t
    sudo logrotate -d /etc/logrotate.d/repcoach-ai

Only continue if both validation commands succeed.

Then:

    sudo systemctl restart repcoach-backend
    sudo systemctl reload nginx

## Production configuration verification

After restart:

    sudo systemctl is-active repcoach-backend
    sudo ss -ltnp | grep '127.0.0.1:8787'
    sudo nginx -T | grep -F 'server_name repcoach-ai.duckdns.org'
    sudo nginx -T | grep -F 'client_max_body_size 16k'
    sudo nginx -T | grep -F 'limit_req zone=repcoach_api'
    sudo nginx -T | grep -F 'proxy_read_timeout 22s'
    sudo nginx -T | grep -F 'location = /privacy-policy.html'
    sudo nginx -T | grep -F 'location = /health'
    sudo nginx -T | grep -F 'location = /ready'

TLS/certbot:

    sudo certbot certificates
    systemctl status certbot.timer --no-pager

Required public behavior:

- HTTP redirects to HTTPS.
- HTTPS certificate validates for repcoach-ai.duckdns.org.
- HSTS is present on HTTPS responses.
- X-Content-Type-Options is nosniff.
- Cache-Control is no-store.
- request body limit is 16 KiB.
- feedback endpoint is POST-only.
- rate limit config is active.
- backend read timeout is 22 seconds.
- /health is process-only.
- /ready validates local provider configuration without consuming Gemini quota.
- /privacy-policy.html serves the B4 bilingual policy.

## Public production smoke

Use synthetic data only:

    cd rep-counter-ai-main/backend
    python3 tools/production_smoke.py

The smoke verifies:

- HTTP to HTTPS redirect;
- TLS hostname validation;
- GET /health;
- GET /ready;
- GET /privacy-policy.html;
- POST-only method guard;
- 16 KiB body-size enforcement;
- POST /v1/workout-feedback with contracts/workout_feedback_v2.json;
- response schema version;
- X-Request-ID;
- feedback latency stays inside the 25 second Flutter budget;
- obvious secret/upstream error markers are absent from public responses.

Do not use a real user workout for release testing.

## Safe-log verification

The public smoke prints the feedback request ID. On the VPS, use only that request ID to verify logging behavior:

    request_id=<32-hex-id-from-smoke>

    sudo grep -F "request_id=$request_id" /var/log/nginx/repcoach-ai.access.log
    sudo journalctl -u repcoach-backend --since "-10 min" --no-pager | grep -F "\"request_id\":\"$request_id\""

Expected log data is operational metadata only. The lines must not contain:

- the workout JSON body;
- consent_version;
- exercise/reps/sets/quality values;
- Gemini prompt;
- Gemini response text;
- GEMINI_API_KEY;
- x-goog-api-key.

Do not paste production log lines containing IP addresses into public issues or commits.

## Rollback

If deployment validation or smoke fails, roll back immediately rather than debugging by editing production files in place.

Assuming backup points to the pre-deploy directory created above:

    sudo systemctl stop repcoach-backend

    sudo cp -a "$backup/app/server.py" /home/nduythanh/apps/repcoach-backend/server.py 2>/dev/null || true
    sudo cp -a "$backup/app/ai_provider.py" /home/nduythanh/apps/repcoach-backend/ai_provider.py 2>/dev/null || true
    if sudo test -d "$backup/app/static"; then
      sudo rm -rf /home/nduythanh/apps/repcoach-backend/static
      sudo cp -a "$backup/app/static" /home/nduythanh/apps/repcoach-backend/static
    fi

    sudo cp -a "$backup/system/repcoach-backend.service" /etc/systemd/system/repcoach-backend.service 2>/dev/null || true
    sudo cp -a "$backup/system/nginx-site" /etc/nginx/sites-available/repcoach-ai 2>/dev/null || true
    sudo cp -a "$backup/system/rate-limit.conf" /etc/nginx/conf.d/repcoach-rate-limit.conf 2>/dev/null || true
    sudo cp -a "$backup/system/logrotate" /etc/logrotate.d/repcoach-ai 2>/dev/null || true

    sudo systemctl daemon-reload
    sudo nginx -t
    sudo systemctl start repcoach-backend
    sudo systemctl reload nginx

Re-run health/privacy smoke after rollback.

### AI-unavailable fallback

If the backend runtime is healthy but provider billing/terms/configuration cannot be approved, do not send requests to an unverified provider mode. Leave AI unavailable. Core workout counting/history remains local-first and B6 tests prove an AI failure does not destroy the local workout.

A controlled AI-unavailable state is preferable to bypassing the paid-mode guard.

## Release evidence to retain privately

Keep a private release note with:

- release commit SHA;
- deployment UTC timestamp;
- operator;
- pre-deploy backup path;
- exact Google project name/identifier and observed Paid Tier;
- billing verification timestamp;
- provider terms review decision;
- nginx -t result;
- systemd active result;
- public smoke result and latency;
- feedback request ID;
- safe-log verification result;
- rollback outcome if rollback was used.

Do not store API keys, billing account IDs, payment details, SSH private keys or raw production log dumps in that record.

## Acceptance

B7 is complete only when:

1. provider billing and terms gates are resolved;
2. production files/config are deployed from the reviewed release commit;
3. systemd/Nginx/TLS/logrotate checks pass;
4. public production smoke passes using synthetic data;
5. safe logs are verified by request ID;
6. rollback path is confirmed;
7. no secret is exposed.

Until then, the backend is not considered ready for App Store review traffic.
