# RepCoach AI workout-feedback backend

This service accepts a small JSON workout summary and forwards a constrained prompt to the configured AI provider. Camera images, imported videos, audio, and raw pose landmarks are not accepted or transmitted.

## Production endpoint

- Health: `GET https://repcoach-ai.duckdns.org/health`
- Readiness: `GET https://repcoach-ai.duckdns.org/ready`
- Feedback: `POST https://repcoach-ai.duckdns.org/v1/workout-feedback`

## Health, readiness and request IDs

`GET /health` is a process-liveness check only:

```json
{"status":"ok"}
```

It does not resolve provider configuration and never calls the configured external provider.

`GET /ready` validates that the required provider configuration can be constructed locally:

```json
{"status":"ready"}
```

or, without exposing which secret/config value is missing:

```json
{"status":"not_ready"}
```

Readiness does not call Groq/Gemini or consume provider quota.

Every backend JSON response includes `X-Request-ID`. Nginx generates a random request ID and forwards it to the backend; direct backend requests receive a server-generated random ID. Only bounded 32-character hexadecimal IDs are accepted from an upstream proxy, so arbitrary client tracking strings are not propagated. The same ID is present in structured backend logs for one-request debugging.

The mobile API does not enable browser CORS. `OPTIONS /v1/workout-feedback` is rejected like other unsupported methods; mobile Flutter requests do not require CORS.

## AI provider boundary

The HTTP API depends on an `AiProvider` interface. Provider-specific HTTP, prompt construction, response parsing, and timeout behavior live in `ai_provider.py`, not in the route handler.

Current production provider:

```text
AI_PROVIDER=groq
GROQ_API_KEY=
GROQ_MODEL=openai/gpt-oss-20b
```

`openai/gpt-oss-20b` is the default Groq production model used by RepCoach. The legacy Gemini adapter remains available for a future separately approved deployment, but Gemini unpaid mode remains rejected and is not the current production path.

### Current Groq data contract

RepCoach sends only the minimized aggregate workout prompt described below. According to GroqCloud's current data documentation, inference customer data is not retained by default except when needed for features that require retention or for platform reliability/abuse investigation; Groq documents up to 30 days for ordinary inference reliability/abuse monitoring. Groq offers Zero Data Retention controls, but RepCoach does not currently claim ZDR is enabled.

Groq's current Services Agreement allows a customer to integrate Groq APIs into a Customer Application and make AI services available to End Users. The developer remains responsible for applicable laws and the provider/model terms.

See `docs/groq-provider.md` for the provider verification record.

## Prompt/response constraints

Only whitelisted aggregate workout-summary fields enter the provider prompt. The provider adapter excludes contract metadata and unrelated product data such as identity, routine libraries, full workout/PR history, badges/streaks, camera/video content, and raw landmarks.

The provider is instructed to return concise, non-medical workout feedback. Provider results are rejected when missing, malformed, empty, larger than the provider-response byte cap, or longer than 2,000 characters.

## Workout-feedback API contract

The endpoint temporarily accepts both the current v1 client contract and v2.

### Compatibility

- Missing `schema_version` is treated as legacy v1.
- `schema_version: 1` remains accepted while the Flutter client is still on v1.
- `schema_version: 2` requires `consent_version`.
- Unknown fields are rejected instead of silently entering the contract.
- `schema_version` and `consent_version` are contract/audit metadata and are not sent to the AI provider.

### v2 request example

```json
{
  "schema_version": 2,
  "consent_version": "2026-10-01-groq",
  "exercise": "push_up",
  "duration_seconds": 780,
  "reps": 28,
  "sets": 3,
  "target_reps": 30,
  "goal_reached": false,
  "placement_score": 91,
  "pose_frames": 3901,
  "pose_lost_frames": 84,
  "flagged_reps": 4,
  "avg_rep_sec": 1.6,
  "avg_amplitude": 52.0,
  "amplitude_drop_percent": 8.0,
  "left_right_diff_percent": 5.0,
  "quality_score": 84,
  "has_enough_data": true,
  "locale": "vi"
}
```

Allowed exercises currently match the app catalog:

```text
push_up
pull_up
curl
overhead_extension
```

Allowed locales:

```text
vi
en
```

Validation includes required fields, JSON content type, strict primitive types, non-negative bounded numeric values, exercise/locale allowlists, `pose_lost_frames <= pose_frames`, `flagged_reps <= reps`, and strict unknown-field rejection.

### Success response

```json
{
  "schema_version": 1,
  "feedback": "..."
}
```

Existing Flutter clients remain compatible because they already read the `feedback` field and ignore the added response metadata.

## Stable failure contract

The public endpoint does not return stack traces, API-key/configuration details, provider response bodies, or raw provider error bodies.

| HTTP | error | Meaning |
| --- | --- | --- |
| 400 | `INVALID_REQUEST` | Malformed JSON, wrong content type, or validation failure |
| 405 | `INVALID_REQUEST` | `/v1/workout-feedback` called with a non-POST method |
| 413 | `INVALID_REQUEST` | Request body exceeds 16 KiB |
| 429 | `RATE_LIMITED` | Nginx per-IP limit reached; response includes `Retry-After: 60` |
| 502 | `AI_RESPONSE_INVALID` | Provider returned an unusable/malformed/overlong response |
| 503 | `AI_UNAVAILABLE` | Provider/configuration/network unavailable |
| 504 | `AI_TIMEOUT` | Provider exceeded the bounded timeout budget |
| 500 | `SERVER_ERROR` | Unexpected server failure |

## Timeout budget

The layers are deliberately ordered so an inner layer fails before an outer caller gives up:

```text
Provider connect timeout:   5 s
Provider response timeout: 15 s
Backend total budget:    20 s
Nginx backend read:      22 s
Flutter request timeout: 25 s
```

The backend does not wait indefinitely for the configured provider.

## Privacy-safe operational logging

Application logs contain operational metadata only:

```text
timestamp
request_id
route
method
status
duration_ms
coarse request_size bucket
error_code when present
provider_status_class when present
```

The random request ID exists only to correlate one request through proxy/backend diagnostics and is not a user identifier.

Application logs never contain the workout body, AI prompt, AI response text, API key, secret headers, or stack traces.

Nginx uses the `repcoach_meta` format and records only IP address plus request metadata required for operations/rate limiting: timestamp, random request ID, method, URI path, status, response bytes, and request duration. It does not log request bodies, authorization headers, referrer, or user-agent in the RepCoach access log.

The provided `deploy/repcoach-ai.logrotate` rotates RepCoach Nginx access/error logs daily and keeps 14 rotations with compression. Backend structured metadata is emitted to the host system journal; its retention remains controlled by VPS journal settings.

## Privacy Policy and AI consent

The canonical public policy source is:

```text
backend/static/privacy-policy.html
```

Production serves it at:

```text
https://repcoach-ai.duckdns.org/privacy-policy.html
```

The current policy/consent contract is:

- effective date: `2026-10-01`;
- AI consent version: `2026-10-01-groq`;
- production provider: GroqCloud;
- automatic AI: off by default, opt-in, new workouts only;
- manual AI: per-request confirmation;
- the Groq provider change invalidates the older automatic-AI consent key;
- disabling AI affects future requests and cannot recall an already-sent request;
- public policy is bilingual VI/EN and contains no Android-only settings instructions.

## Rate limiting and request size

- Nginx rate zone: `10r/m` per source IP.
- Feedback burst: `5`, no delay.
- Health burst: `10`, no delay.
- Nginx and application body limit: 16 KiB.
- Rate-limit response: HTTP 429 + `{"error":"RATE_LIMITED"}` + `Retry-After: 60`.
- No account ID, device fingerprint, or workout identifier is introduced for rate limiting.

## Backend tests

Tests use only the Python standard library, fakes, and mocks; they do not call live external providers:

```bash
cd rep-counter-ai-main/backend
python3 -m unittest discover -s tests -v
```

Coverage includes contract validation, legacy-schema compatibility, malformed/unknown-field rejection, request-size and method rejection, health/readiness behavior, request-ID propagation, no-CORS behavior, timeout/error mapping, provider adapter swapping, required service-mode guards, prompt minimization, empty/invalid/overlong provider responses, no-content logging checks, privacy contract checks, and deploy configuration checks.

## Backend CI

Backend tests run in a dedicated GitHub Actions workflow, separate from expensive iOS video replay:

```text
.github/workflows/backend-ci.yml
```

The workflow runs Python compile checks and the complete standard-library unittest suite for backend changes. It does not inject a Gemini API key and does not make live Gemini requests.

For an Nginx deployment, validate syntax before reload:

```bash
sudo nginx -t
```

## VPS layout

- Application: `/home/nduythanh/apps/repcoach-backend`
- Service: `/etc/systemd/system/repcoach-backend.service`
- Nginx site: `/etc/nginx/sites-available/repcoach-ai`
- Rate limit/log format: `/etc/nginx/conf.d/repcoach-rate-limit.conf`
- Log rotation: `/etc/logrotate.d/repcoach-ai`
- TLS certificate: `/etc/letsencrypt/live/repcoach-ai.duckdns.org/`

The Python server listens only on `127.0.0.1:8787`. Nginx is the only public entry point and enforces HTTPS, the body limit, method restriction, rate limiting, bounded proxy timeouts, and security headers.

## Production release

The B7 production deployment, provider gate, public smoke, safe-log verification and rollback procedure is documented in:

```text
docs/production-release.md
```

Public production smoke uses synthetic data only:

```bash
cd rep-counter-ai-main/backend
python3 tools/production_smoke.py
```

A passing smoke verifies the deployed API behavior, not the presence or value of the Groq secret. The deployment workflow checks that the production VPS is explicitly configured for `AI_PROVIDER=groq` and that a non-empty `GROQ_API_KEY` exists without printing it.

## Deployment notes

Install/update the deployment files, then validate before reload:

```bash
sudo install -d -m 0755 /home/nduythanh/apps/repcoach-backend/static
sudo cp static/privacy-policy.html /home/nduythanh/apps/repcoach-backend/static/privacy-policy.html
sudo cp deploy/repcoach-ai.nginx /etc/nginx/sites-available/repcoach-ai
sudo cp deploy/repcoach-rate-limit.conf /etc/nginx/conf.d/repcoach-rate-limit.conf
sudo cp deploy/repcoach-ai.logrotate /etc/logrotate.d/repcoach-ai
sudo nginx -t
sudo logrotate -d /etc/logrotate.d/repcoach-ai
sudo systemctl reload nginx
sudo systemctl restart repcoach-backend
```

Before restarting, the production `.env` must contain:

```text
AI_PROVIDER=groq
GROQ_API_KEY=<server secret>
GROQ_MODEL=openai/gpt-oss-20b
BIND_HOST=127.0.0.1
```

After copying the policy, verify `GET /privacy-policy.html` over HTTPS returns 200 with a `text/html; charset=utf-8` content type. Do not deploy policy text without the matching runtime/provider configuration.

## Operations

```bash
sudo systemctl status repcoach-backend
sudo systemctl restart repcoach-backend
sudo journalctl -u repcoach-backend -n 100 --no-pager
sudo nginx -t
sudo systemctl reload nginx
sudo certbot renew --dry-run
```

## Flutter release build

```powershell
flutter build appbundle --release `
  --dart-define=AI_BASE_URL=https://repcoach-ai.duckdns.org
```

Never commit `.env`, `key.properties`, or `upload-keystore.jks`.
