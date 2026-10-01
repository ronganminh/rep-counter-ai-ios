# B7 production release runbook

Status date: **2026-10-01**

This runbook prepares the RepCoach backend for App Store review traffic with **GroqCloud** as the current production AI provider. Source code, a successful request, or the presence of an API-key variable does not by itself prove the live VPS is running the reviewed release.

## Current release status

| Gate | Status | Evidence / action |
| --- | --- | --- |
| B1-B6 merged to main | PASS | API contract, security, privacy, observability and staging integration are on main |
| Groq provider adapter + policy/consent alignment | PASS on B7 branch | Current provider is `groq`; consent version is `2026-10-01-groq` |
| Production Groq secret | OPERATOR REPORTED PRESENT | Deployment preflight verifies only that `GROQ_API_KEY` is non-empty; it never prints the key |
| Production VPS updated to B7 source/config | NOT YET | Public smoke still shows the pre-B5 backend until deployment |
| Public production smoke after deploy | NOT YET | Must pass after the reviewed release is installed |
| Safe production log sample checked by request ID | NOT YET | Performed automatically by guarded deploy workflow |
| Rollback path | PREPARED | Transactional apply + explicit rollback scripts |

Do not mark production ready until deployment, public smoke and safe-log verification pass.

## Groq provider review

Current provider:

    AI_PROVIDER=groq
    GROQ_MODEL=openai/gpt-oss-20b

Official provider sources checked on 2026-10-01:

- https://console.groq.com/docs/models
- https://console.groq.com/docs/openai
- https://console.groq.com/docs/your-data
- https://console.groq.com/docs/legal/services-agreement
- https://console.groq.com/docs/legal/ai-policy

Groq documents `openai/gpt-oss-20b` as a production model and exposes an OpenAI-compatible API.

Current Groq data documentation states that inference customer data is not retained by default, except when a feature requires retention or when needed for platform reliability/troubleshooting/abuse investigation. Ordinary inference reliability/abuse retention is documented as up to 30 days. Groq offers Zero Data Retention controls, but RepCoach does not currently claim ZDR is enabled.

The current Groq Services Agreement says customer Inputs/Outputs are not used to train or fine-tune models unless the customer explicitly permits or instructs that use. It also allows API integration into a Customer Application and making AI Model Services available to End Users. The customer account holder must satisfy Groq's age requirement and remains responsible for applicable laws for minors/personal data. See `docs/groq-provider.md` for the complete provider record.

## Observed live production baseline before B7 deploy

A public synthetic smoke reached the real production hostname and found the live host was still on an older backend/Nginx/privacy deployment:

- HTTP to HTTPS redirect: PASS.
- TLS hostname validation: PASS.
- GET /health: old pre-B5 body.
- GET /ready: 404.
- Privacy Policy: stale.
- feedback method/body error contract: stale.
- synthetic v2 feedback: response missing the current response schema metadata.

Working TLS or an AI response is not evidence that B7 is deployed.

## Production topology

Public origin:

    https://repcoach-ai.duckdns.org

Process:

    nginx :443
      -> 127.0.0.1:8787
      -> repcoach-backend.service
      -> Python server.py
      -> AiProvider
      -> GroqProvider
      -> api.groq.com

The backend has no user-account database and no workout-history database.

## Process management

Service:

    repcoach-backend

Working directory:

    /home/nduythanh/apps/repcoach-backend

Environment file:

    /home/nduythanh/apps/repcoach-backend/.env

The .env file is a server secret and must never be copied into Git, CI artifacts, screenshots, tickets, or release notes.

Useful commands:

    sudo systemctl restart repcoach-backend
    sudo systemctl status repcoach-backend --no-pager
    sudo journalctl -u repcoach-backend -n 100 --no-pager

Nginx logs:

    /var/log/nginx/repcoach-ai.access.log
    /var/log/nginx/repcoach-ai.error.log

## Production environment preflight

Required values:

    AI_PROVIDER=groq
    GROQ_API_KEY=<server secret>
    GROQ_MODEL=openai/gpt-oss-20b
    PORT=8787
    BIND_HOST=127.0.0.1

Safe manual check that does not print the API key:

    cd /home/nduythanh/apps/repcoach-backend

    grep -E '^(AI_PROVIDER|GROQ_MODEL|BIND_HOST)=' .env

    grep -q '^GROQ_API_KEY=.' .env       && echo 'GROQ_API_KEY=PRESENT'       || echo 'GROQ_API_KEY=MISSING'

The guarded CI deploy additionally requires non-interactive sudo. It never passes a sudo password through Actions. If the VPS intentionally requires an interactive sudo password, keep the CI deploy locked and run the reviewed apply script manually from an SSH terminal; the script will use normal sudo prompts.

## Guarded GitHub Actions deployment

Workflow:

    .github/workflows/production-deploy.yml

Production deployment is locked unless this reviewed marker exists:

    rep-counter-ai-main/backend/deploy/B7_DEPLOY_APPROVED

with exact content:

    DEPLOY_B7_2026_10_01

The workflow uses the repository secret:

    VPS_SSH_KEY

The private key must never be committed or pasted into issues/chat. SSH host-key checking is pinned to the ed25519 host key already trusted by the operator workstation.

When approved and passwordless narrow sudo is available, the workflow:

1. validates the production Groq configuration without printing secrets;
2. requires passwordless/non-interactive sudo;
3. uploads only reviewed backend/config files;
4. creates a pre-deploy backup;
5. validates Python, Nginx and logrotate;
6. restarts the service and reloads Nginx;
7. runs synthetic public production smoke;
8. verifies privacy-safe logs using the returned request ID;
9. rolls back automatically when a post-deploy check fails.

## Host package prerequisites

The deploy requires `nginx`, `logrotate`, `systemctl` and `ss` on the VPS. The apply script checks these dependencies before creating a release backup or replacing production files. On a minimized Ubuntu host, install a missing `logrotate` package before retrying:

    sudo apt-get update
    sudo apt-get install -y logrotate

Then verify:

    command -v logrotate
    sudo logrotate -d /etc/logrotate.d/repcoach-ai

## Manual interactive-sudo deployment

If `sudo -n` is unavailable, do not weaken the VPS to `NOPASSWD: ALL`. From an SSH terminal, check out the reviewed B7 commit, then run:

    cd <repository-root>
    bash rep-counter-ai-main/backend/deploy/b7_apply.sh rep-counter-ai-main/backend

Enter the sudo password only into the VPS terminal when prompted. The script performs the same preflight, backup, Nginx/logrotate validation and restart steps. It prints the backup path on success. Then run the public production smoke from a trusted checkout and complete the request-ID log verification manually.

## Files deployed

Application:

    backend/server.py
    backend/ai_provider.py
    backend/static/privacy-policy.html

System configuration:

    backend/deploy/repcoach-backend.service
    backend/deploy/repcoach-ai.nginx
    backend/deploy/repcoach-rate-limit.conf
    backend/deploy/repcoach-ai.logrotate

Deployment helpers:

    backend/deploy/b7_apply.sh
    backend/deploy/b7_rollback.sh

The deployment never replaces the production .env.

## Public production smoke

After deployment:

    cd rep-counter-ai-main/backend
    python3 tools/production_smoke.py

The smoke uses only the shared synthetic v2 fixture and verifies:

- HTTP to HTTPS redirect;
- TLS hostname validation;
- GET /health;
- GET /ready;
- current bilingual Privacy Policy and consent version;
- POST-only method guard;
- 16 KiB body-size enforcement;
- POST /v1/workout-feedback;
- response schema;
- X-Request-ID;
- latency within the Flutter 25 second budget;
- absence of obvious provider-secret/upstream markers.

Do not use a real user workout for release testing.

## Safe-log verification

The smoke prints the feedback request ID. The deploy workflow correlates that ID through Nginx and the backend journal.

Expected correlated logs contain only operational metadata. They must not contain:

- workout JSON;
- consent_version;
- exercise/reps/sets/quality values;
- provider prompt;
- provider response;
- GROQ_API_KEY;
- Authorization bearer value;
- legacy Gemini secrets.

Do not paste production log lines containing IP addresses into public issues or commits.

## Rollback

The transactional apply script creates a root-only backup under:

    /var/backups/repcoach-b7/<UTC timestamp>

If apply itself fails after backup creation it attempts local rollback automatically.

If public smoke or log verification fails after apply, the GitHub workflow calls:

    backend/deploy/b7_rollback.sh

Rollback restores the previous backend files and system configuration, validates Nginx, restarts the service and reloads Nginx.

If Groq is temporarily unavailable, keep the app local-first and let AI requests fail with the stable optional-AI error state rather than bypassing provider/configuration guards.

## Release evidence to retain privately

Keep:

- release commit SHA;
- deployment UTC timestamp;
- operator;
- backup path;
- Nginx validation result;
- systemd active result;
- public smoke result and latency;
- feedback request ID;
- safe-log verification result;
- rollback result if used.

Do not retain API keys, SSH private keys, payment data or raw production log dumps in the repository.

## Acceptance

B7 is complete only when:

1. Groq provider/policy/consent tests pass;
2. production .env is configured for Groq;
3. production files/config are deployed from the reviewed release;
4. systemd/Nginx/TLS/logrotate checks pass;
5. public production smoke passes;
6. safe logs are verified by request ID;
7. rollback remains available;
8. no secret is exposed.
