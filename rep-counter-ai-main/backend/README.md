# RepCoach AI workout-feedback backend

This service accepts a small JSON workout summary and forwards a constrained prompt to Google Gemini. Camera images, imported videos, audio, and raw pose landmarks are not accepted or transmitted.

## Production endpoint

- Health: `https://repcoach-ai.duckdns.org/health`
- Feedback: `POST https://repcoach-ai.duckdns.org/v1/workout-feedback`

## Workout-feedback API contract

The endpoint temporarily accepts both the current v1 client contract and v2.

### Compatibility

- Missing `schema_version` is treated as legacy v1.
- `schema_version: 1` remains accepted while the Flutter client is still on v1.
- `schema_version: 2` requires `consent_version`.
- Unknown fields are rejected instead of silently entering the contract.
- `schema_version` and `consent_version` are contract/audit metadata and are not sent to Gemini.

### v2 request example

```json
{
  "schema_version": 2,
  "consent_version": "2026-10-01",
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

Validation includes required fields, strict primitive types, non-negative bounded numeric values, exercise/locale allowlists, `pose_lost_frames <= pose_frames`, `flagged_reps <= reps`, and strict unknown-field rejection.

### Success response

```json
{
  "schema_version": 1,
  "feedback": "..."
}
```

Existing Flutter clients remain compatible because they already read the `feedback` field and ignore the added response metadata.

Stable error-code work is intentionally deferred to Track B phase B2.

## Backend tests

The contract/validation suite uses only the Python standard library and does not call Gemini:

```bash
cd rep-counter-ai-main/backend
python3 -m unittest discover -s tests -v
```

## VPS layout

- Application: `/home/nduythanh/apps/repcoach-backend`
- Service: `/etc/systemd/system/repcoach-backend.service`
- Nginx site: `/etc/nginx/sites-available/repcoach-ai`
- Rate limit: `/etc/nginx/conf.d/repcoach-rate-limit.conf`
- TLS certificate: `/etc/letsencrypt/live/repcoach-ai.duckdns.org/`

The Python server listens only on `127.0.0.1:8787`. Nginx is the only public entry point and enforces HTTPS, a 16 KB body limit, request rate limiting, and security headers.

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
