# RepCoach production release runbook

Status date: **2026-10-01**

RepCoach production uses **GroqCloud** for optional workout-summary AI feedback. Core workout counting, local history and local product features remain usable when the backend or AI provider is unavailable.

## Current production release

| Item | Status |
| --- | --- |
| Production AI provider | PASS — GroqCloud |
| Model | `openai/gpt-oss-20b` |
| Consent version | `2026-10-01-groq` |
| Deployed reviewed source SHA | `c5762d0f00acef641546d6a2e3ffb3d8d4ce7502` |
| B7 merge commit on `main` | `84621249530f1751d73b8412b7e4ca646fd93aa1` |
| Public production smoke | PASS |
| Privacy Policy | PASS |
| Safe-log correlation | PASS |
| Rollback backup from successful deploy | `/var/backups/repcoach-b7/20261001T103658Z` |

Final B7 production smoke verified:

- HTTP to HTTPS redirect;
- TLS hostname validation;
- `GET /health`;
- `GET /ready`;
- `GET /privacy-policy.html`;
- POST-only method behavior;
- 16 KiB request-size behavior;
- synthetic `POST /v1/workout-feedback`;
- stable response schema;
- `X-Request-ID`;
- latency within the Flutter request budget;
- no obvious public provider-secret/upstream leakage.

The successful synthetic feedback request completed in about 1.5 seconds. Correlated Nginx/backend logs contained operational metadata only and no workout body, AI prompt/response, consent value, API key or Authorization secret.

## Production topology

    https://repcoach-ai.duckdns.org
      -> nginx :443
      -> 127.0.0.1:8787
      -> repcoach-backend.service
      -> Python server.py
      -> AiProvider
      -> GroqProvider
      -> api.groq.com

The backend has no user-account database and no workout-history database.

## Runtime locations

Service:

    repcoach-backend

Application directory:

    /home/nduythanh/apps/repcoach-backend

Environment file:

    /home/nduythanh/apps/repcoach-backend/.env

Nginx logs:

    /var/log/nginx/repcoach-ai.access.log
    /var/log/nginx/repcoach-ai.error.log

The production `.env` is a server secret and must never be committed, copied into CI artifacts, screenshots, tickets or release notes.

## Required production configuration

The production environment must contain:

    AI_PROVIDER=groq
    GROQ_API_KEY=<server secret>
    GROQ_MODEL=openai/gpt-oss-20b
    PORT=8787
    BIND_HOST=127.0.0.1

Safe verification must test only presence/expected non-secret values and must never print the API key.

## Deployment model

The VPS intentionally requires an interactive sudo password. Do **not** weaken it to `NOPASSWD: ALL` for CI.

Production deployment is therefore a reviewed **manual interactive-sudo operation**. GitHub Actions may perform read-only checks, but it must not pretend to be able to complete privileged deployment when the host requires an interactive sudo prompt.

From an SSH terminal, check out the exact reviewed release SHA and run:

    cd <repository-root>

    bash rep-counter-ai-main/backend/deploy/b7_apply.sh \
      rep-counter-ai-main/backend \
      /home/nduythanh/apps/repcoach-backend

Enter the sudo password only in the VPS terminal when prompted.

The apply script:

1. validates Groq configuration without printing secrets;
2. compiles backend Python before privileged writes;
3. validates host dependencies;
4. creates a root-only transactional backup;
5. installs application/system configuration;
6. validates Nginx and logrotate;
7. restarts the backend and reloads Nginx;
8. waits up to 10 seconds for local `/health`;
9. validates the effective Nginx configuration;
10. prints `BACKUP_PATH=...` only after all post-deploy checks pass.

## Host prerequisites

Required commands:

    nginx
    logrotate
    systemctl
    ss
    curl
    python3

On a minimized Ubuntu host, install logrotate if missing:

    sudo apt-get update
    sudo apt-get install -y logrotate

## Read-only production operations check

Workflow:

    .github/workflows/production-ops-check.yml

This workflow is manual-only and read-only. It uses the repository `VPS_SSH_KEY` secret and pinned SSH host key to verify:

- expected non-secret Groq configuration;
- API key presence without printing its value;
- service liveness;
- local `/health`;
- deployed `server.py`, `ai_provider.py` and Privacy Policy hashes against the checked-out source;
- public `/health`, `/ready` and Privacy Policy.

It does not run sudo, restart services or call Groq directly.

## Public production smoke

Workflow:

    .github/workflows/production-readiness.yml

The live smoke is **manual-only** after deployment. This avoids treating a not-yet-deployed PR as a production failure.

It uses synthetic/non-personal data only and can also be run locally:

    cd rep-counter-ai-main/backend
    python3 tools/production_smoke.py

The full smoke does call the production workout-feedback route and therefore exercises the configured AI provider.

## Privacy Policy serving

Canonical source:

    backend/static/privacy-policy.html

Public URL:

    https://repcoach-ai.duckdns.org/privacy-policy.html

Nginx proxies the Privacy Policy route to the backend. The backend reads the canonical static file as the service user. Production does not make the private application/home directory traversable by the Nginx worker.

## Safe logging

Application logs may contain only operational metadata such as:

    timestamp
    request_id
    route
    method
    status
    duration_ms
    coarse request_size
    error_code
    provider_status_class

They must not contain:

- workout JSON;
- consent_version;
- exercise/reps/sets/quality values;
- provider prompt;
- provider response;
- `GROQ_API_KEY`;
- Authorization bearer value;
- legacy Gemini secrets.

Nginx access logs contain source IP plus request metadata needed for operations/rate limiting. RepCoach Nginx logs rotate daily and keep 14 rotations with compression.

## Safe-log release check

After a synthetic production smoke, use its request ID:

    RID="<request-id>"

    sudo grep -F "$RID" /var/log/nginx/repcoach-ai.access.log

    sudo journalctl -u repcoach-backend --since "-15 min" --no-pager \
      | grep -F "$RID"

Verify the correlated lines contain metadata only.

## Rollback

Each apply creates a root-only backup under:

    /var/backups/repcoach-b7/<UTC timestamp>

Explicit rollback:

    bash rep-counter-ai-main/backend/deploy/b7_rollback.sh \
      /var/backups/repcoach-b7/<UTC timestamp>

The rollback restores both content and prior present/absent state for managed files, validates Nginx, restarts the service and reloads Nginx.

If Groq is unavailable, do not bypass provider/configuration/privacy guards. Optional AI may fail while the app remains local-first.

## Provider records

Current production provider record:

    docs/groq-provider.md

Legacy non-production Gemini record:

    docs/gemini-service-mode.md

Any future provider switch requires a fresh terms/data-flow/privacy/consent review before deployment.

## Release evidence

For each production release retain privately:

- reviewed source SHA;
- deployment UTC timestamp;
- operator;
- backup path;
- Nginx validation result;
- backend service/health result;
- production smoke result and latency;
- synthetic feedback request ID;
- safe-log verification result;
- rollback result if used.

Do not retain API keys, SSH private keys, payment data or raw production log dumps in the repository.
