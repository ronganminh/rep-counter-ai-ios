# RepCoach AI workout-feedback backend

This service accepts a small JSON workout summary and forwards a constrained prompt to Google Gemini. Camera images, imported videos, and raw pose landmarks are not accepted or transmitted.

## Production endpoint

- Health: `https://repcoach-ai.duckdns.org/health`
- Feedback: `POST https://repcoach-ai.duckdns.org/v1/workout-feedback`

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
