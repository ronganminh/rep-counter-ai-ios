#!/usr/bin/env bash
set -euo pipefail

stage_dir="${1:?stage_dir required}"
app_dir="${2:-/home/nduythanh/apps/repcoach-backend}"

if [[ ! -d "$stage_dir" ]]; then
  echo "stage directory missing" >&2
  exit 2
fi
if [[ ! -f "$app_dir/.env" ]]; then
  echo "production .env missing" >&2
  exit 2
fi

# Safe configuration assertions: never print secret values.
grep -qx 'AI_PROVIDER=groq' "$app_dir/.env"
grep -q '^GROQ_API_KEY=.' "$app_dir/.env"
grep -qx 'GROQ_MODEL=openai/gpt-oss-20b' "$app_dir/.env"
grep -qx 'BIND_HOST=127.0.0.1' "$app_dir/.env"

# CI checks non-interactive sudo before invoking this script. When an operator
# runs the script manually, normal sudo may prompt on the operator's TTY.
python3 -m py_compile "$stage_dir/server.py" "$stage_dir/ai_provider.py"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="/var/backups/repcoach-b7/$stamp"
backup_ready=0
completed=0

rollback_local() {
  code=$?
  if [[ "$completed" -eq 0 && "$backup_ready" -eq 1 ]]; then
    echo "Deploy failed; restoring pre-deploy backup" >&2
    sudo systemctl stop repcoach-backend || true
    [[ -f "$backup/app/server.py" ]] && install -m 0644 "$backup/app/server.py" "$app_dir/server.py"
    [[ -f "$backup/app/ai_provider.py" ]] && install -m 0644 "$backup/app/ai_provider.py" "$app_dir/ai_provider.py"
    if sudo test -d "$backup/app/static"; then
      rm -rf "$app_dir/static"
      cp -a "$backup/app/static" "$app_dir/static"
    fi
    sudo test -f "$backup/system/repcoach-backend.service" && sudo cp -a "$backup/system/repcoach-backend.service" /etc/systemd/system/repcoach-backend.service || true
    sudo test -f "$backup/system/nginx-site" && sudo cp -a "$backup/system/nginx-site" /etc/nginx/sites-available/repcoach-ai || true
    sudo test -f "$backup/system/rate-limit.conf" && sudo cp -a "$backup/system/rate-limit.conf" /etc/nginx/conf.d/repcoach-rate-limit.conf || true
    sudo test -f "$backup/system/logrotate" && sudo cp -a "$backup/system/logrotate" /etc/logrotate.d/repcoach-ai || true
    sudo systemctl daemon-reload || true
    sudo nginx -t || true
    sudo systemctl start repcoach-backend || true
    sudo systemctl reload nginx || true
  fi
  exit "$code"
}
trap rollback_local EXIT

sudo install -d -m 0700 "$backup/app" "$backup/system"
[[ -f "$app_dir/server.py" ]] && sudo cp -a "$app_dir/server.py" "$backup/app/server.py"
[[ -f "$app_dir/ai_provider.py" ]] && sudo cp -a "$app_dir/ai_provider.py" "$backup/app/ai_provider.py"
[[ -d "$app_dir/static" ]] && sudo cp -a "$app_dir/static" "$backup/app/static"
sudo test -f /etc/systemd/system/repcoach-backend.service && sudo cp -a /etc/systemd/system/repcoach-backend.service "$backup/system/repcoach-backend.service" || true
sudo test -f /etc/nginx/sites-available/repcoach-ai && sudo cp -a /etc/nginx/sites-available/repcoach-ai "$backup/system/nginx-site" || true
sudo test -f /etc/nginx/conf.d/repcoach-rate-limit.conf && sudo cp -a /etc/nginx/conf.d/repcoach-rate-limit.conf "$backup/system/rate-limit.conf" || true
sudo test -f /etc/logrotate.d/repcoach-ai && sudo cp -a /etc/logrotate.d/repcoach-ai "$backup/system/logrotate" || true
backup_ready=1

install -d -m 0755 "$app_dir/static"
install -m 0644 "$stage_dir/server.py" "$app_dir/server.py"
install -m 0644 "$stage_dir/ai_provider.py" "$app_dir/ai_provider.py"
install -m 0644 "$stage_dir/static/privacy-policy.html" "$app_dir/static/privacy-policy.html"

sudo install -m 0644 "$stage_dir/deploy/repcoach-backend.service" /etc/systemd/system/repcoach-backend.service
sudo install -m 0644 "$stage_dir/deploy/repcoach-ai.nginx" /etc/nginx/sites-available/repcoach-ai
sudo install -m 0644 "$stage_dir/deploy/repcoach-rate-limit.conf" /etc/nginx/conf.d/repcoach-rate-limit.conf
sudo install -m 0644 "$stage_dir/deploy/repcoach-ai.logrotate" /etc/logrotate.d/repcoach-ai

sudo systemctl daemon-reload
sudo nginx -t
sudo logrotate -d /etc/logrotate.d/repcoach-ai >/dev/null
sudo systemctl restart repcoach-backend
sudo systemctl reload nginx

sudo systemctl is-active --quiet repcoach-backend
sudo ss -ltn | grep -F '127.0.0.1:8787' >/dev/null
sudo nginx -T 2>/dev/null | grep -F 'client_max_body_size 16k;' >/dev/null
sudo nginx -T 2>/dev/null | grep -F 'limit_req zone=repcoach_api' >/dev/null
sudo nginx -T 2>/dev/null | grep -F 'proxy_read_timeout 22s;' >/dev/null
sudo nginx -T 2>/dev/null | grep -F 'location = /privacy-policy.html' >/dev/null
sudo nginx -T 2>/dev/null | grep -F 'location = /health' >/dev/null
sudo nginx -T 2>/dev/null | grep -F 'location = /ready' >/dev/null

completed=1
trap - EXIT
printf 'BACKUP_PATH=%s\n' "$backup"
