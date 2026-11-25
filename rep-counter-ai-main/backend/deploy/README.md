# backend/deploy

Files that run the RepCoach AI backend and its web pages on the VPS
(`repcoach-ai.duckdns.org`).

| File | What it is |
|---|---|
| `repcoach-ai.nginx` | nginx site (HTTPS, rate limits, one `location =` per public page and API route) |
| `repcoach-backend.service` | systemd unit for `server.py` |
| `repcoach-rate-limit.conf`, `repcoach-ai.logrotate` | nginx rate-limit zone, log rotation |
| `b7_apply.sh`, `b7_rollback.sh` | full backend release (code, unit, nginx, rate limit, logrotate), B-7 |
| `web_apply.sh` | **web pages only**: privacy policy, support, terms, delete account (below) |

No secret is stored here. The production `.env` stays on the VPS only.

## Publish the web pages (`web_apply.sh`)

Installs from the checked-out commit:
- `server.py` and `ai_provider.py`. The page routes live in `server.py`; `/delete-account.html` needs it. The script then restarts `repcoach-backend`, so `/v1/workout-feedback` is unavailable for a few seconds.
- `static/privacy-policy.html`, `support.html`, `terms.html`, `delete-account.html`.
- `repcoach-ai.nginx` as the nginx site, then reloads nginx after `nginx -t`.

It refuses to run unless:
- `EXPECTED_SHA` is set;
- the clone is at that commit;
- the clone has no local changes under `rep-counter-ai-main/backend`.

It backs up everything it replaces first, and restores the backup by itself if any later step fails. Its last check fetches each public page.

### Run it by hand on the VPS

As the app user (`nduythanh`, with sudo), in the existing clone. Replace `<SHA>` with the `main` commit the owner approved:

```bash
cd ~/rep-counter-ai-ios
git fetch origin main
git checkout --detach <SHA>
EXPECTED_SHA=<SHA> bash rep-counter-ai-main/backend/deploy/web_apply.sh
```

Success ends with `WEB_DEPLOY=PASS sha=…` and `BACKUP_PATH=/var/backups/repcoach-web/<UTC time>`. Keep that path.

The defaults match the current VPS. Override any of them with an environment variable before the command:

| Variable | Default |
|---|---|
| `REPO_DIR` | the clone the script is in |
| `APP_DIR` | `/home/nduythanh/apps/repcoach-backend` (the unit's `WorkingDirectory`) |
| `NGINX_SITE` | `/etc/nginx/sites-available/repcoach-ai` (check with `ls -l /etc/nginx/sites-enabled/`) |
| `PUBLIC_URL` | `https://repcoach-ai.duckdns.org` |
| `BACKUP_ROOT` | `/var/backups/repcoach-web` |

Example: `NGINX_SITE=/etc/nginx/sites-available/default EXPECTED_SHA=<SHA> bash rep-counter-ai-main/backend/deploy/web_apply.sh`.

### Roll back from `BACKUP_PATH`

The script rolls back by itself when a step fails. To undo a deployment that passed, restore the backup it printed:

```bash
B=/var/backups/repcoach-web/<UTC time>          # the BACKUP_PATH that was printed
APP=/home/nduythanh/apps/repcoach-backend
sudo cat "$B/DEPLOYED_SHA"                      # the commit that was deployed over this backup
sudo cp -a "$B/server.py" "$B/ai_provider.py" "$APP/"
sudo rm -rf "$APP/static" && sudo cp -a "$B/static" "$APP/static"
sudo cp -a "$B/nginx-site" /etc/nginx/sites-available/repcoach-ai
sudo nginx -t && sudo systemctl reload nginx
sudo systemctl restart repcoach-backend
curl -fsS http://127.0.0.1:8787/health
```

Some files may not exist in the backup:
- If `server.py` or `ai_provider.py` is missing, that file did not exist before the deployment.
- If `static/` is missing, there were no pages before. Then remove `"$APP/static"` instead of copying it back.

Another option is to run `web_apply.sh` again with an older approved commit (`git checkout --detach <old SHA>`, `EXPECTED_SHA=<old SHA>`).

### Tests

`tests/test_web_apply.py` runs the real script against a throwaway clone, app dir and nginx site, with stub `sudo` / `nginx` / `systemctl` / `curl`. It checks five things:
- the script is refused without `EXPECTED_SHA`;
- it is refused at the wrong commit;
- it is refused with local changes;
- a deployment installs the pages and the backup;
- a failed public check restores the backup.

It also runs `bash -n`, plus `shellcheck` when installed.

A GitHub Actions `deploy-web` workflow is not part of this folder yet. It will come in a separate PR, after review.
