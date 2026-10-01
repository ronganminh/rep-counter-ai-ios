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

# Compile before requesting sudo so syntax failures cannot touch production.
python3 -m py_compile "$stage_dir/server.py" "$stage_dir/ai_provider.py"

# Validate host dependencies before creating a backup or replacing any file.
# This intentionally runs before all deployment writes.
sudo sh -c '
  set -eu
  for cmd in nginx logrotate systemctl ss curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "missing deployment dependency: $cmd" >&2
      exit 3
    fi
  done
'

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="/var/backups/repcoach-b7/$stamp"
backup_ready=0
completed=0

rollback_local() {
  code=$?
  if [[ "$completed" -eq 0 && "$backup_ready" -eq 1 ]]; then
    echo "Deploy failed; restoring pre-deploy backup" >&2
    sudo systemctl stop repcoach-backend || true
    if sudo test -f "$backup/app/server.py.present"; then
      sudo cp -a "$backup/app/server.py" "$app_dir/server.py"
    elif sudo test -f "$backup/app/server.py.absent"; then
      sudo rm -f "$app_dir/server.py"
    fi
    if sudo test -f "$backup/app/ai_provider.py.present"; then
      sudo cp -a "$backup/app/ai_provider.py" "$app_dir/ai_provider.py"
    elif sudo test -f "$backup/app/ai_provider.py.absent"; then
      sudo rm -f "$app_dir/ai_provider.py"
    fi
    if sudo test -f "$backup/app/static.present"; then
      sudo rm -rf "$app_dir/static"
      sudo cp -a "$backup/app/static" "$app_dir/static"
    elif sudo test -f "$backup/app/static.absent"; then
      sudo rm -rf "$app_dir/static"
    fi
    if sudo test -f "$backup/system/repcoach-backend.service.present"; then
      sudo cp -a "$backup/system/repcoach-backend.service" /etc/systemd/system/repcoach-backend.service
    elif sudo test -f "$backup/system/repcoach-backend.service.absent"; then
      sudo rm -f /etc/systemd/system/repcoach-backend.service
    fi
    if sudo test -f "$backup/system/nginx-site.present"; then
      sudo cp -a "$backup/system/nginx-site" /etc/nginx/sites-available/repcoach-ai
    elif sudo test -f "$backup/system/nginx-site.absent"; then
      sudo rm -f /etc/nginx/sites-available/repcoach-ai
    fi
    if sudo test -f "$backup/system/rate-limit.conf.present"; then
      sudo cp -a "$backup/system/rate-limit.conf" /etc/nginx/conf.d/repcoach-rate-limit.conf
    elif sudo test -f "$backup/system/rate-limit.conf.absent"; then
      sudo rm -f /etc/nginx/conf.d/repcoach-rate-limit.conf
    fi
    if sudo test -f "$backup/system/logrotate.present"; then
      sudo cp -a "$backup/system/logrotate" /etc/logrotate.d/repcoach-ai
    elif sudo test -f "$backup/system/logrotate.absent"; then
      sudo rm -f /etc/logrotate.d/repcoach-ai
    fi
    sudo systemctl daemon-reload || true
    sudo nginx -t || true
    sudo systemctl start repcoach-backend || true
    sudo systemctl reload nginx || true
  fi
  exit "$code"
}
trap rollback_local EXIT

sudo install -d -m 0700 "$backup/app" "$backup/system"

if [[ -f "$app_dir/server.py" ]]; then
  sudo cp -a "$app_dir/server.py" "$backup/app/server.py"
  sudo touch "$backup/app/server.py.present"
else
  sudo touch "$backup/app/server.py.absent"
fi
if [[ -f "$app_dir/ai_provider.py" ]]; then
  sudo cp -a "$app_dir/ai_provider.py" "$backup/app/ai_provider.py"
  sudo touch "$backup/app/ai_provider.py.present"
else
  sudo touch "$backup/app/ai_provider.py.absent"
fi
if [[ -d "$app_dir/static" ]]; then
  sudo cp -a "$app_dir/static" "$backup/app/static"
  sudo touch "$backup/app/static.present"
else
  sudo touch "$backup/app/static.absent"
fi

if sudo test -f /etc/systemd/system/repcoach-backend.service; then
  sudo cp -a /etc/systemd/system/repcoach-backend.service "$backup/system/repcoach-backend.service"
  sudo touch "$backup/system/repcoach-backend.service.present"
else
  sudo touch "$backup/system/repcoach-backend.service.absent"
fi
if sudo test -f /etc/nginx/sites-available/repcoach-ai; then
  sudo cp -a /etc/nginx/sites-available/repcoach-ai "$backup/system/nginx-site"
  sudo touch "$backup/system/nginx-site.present"
else
  sudo touch "$backup/system/nginx-site.absent"
fi
if sudo test -f /etc/nginx/conf.d/repcoach-rate-limit.conf; then
  sudo cp -a /etc/nginx/conf.d/repcoach-rate-limit.conf "$backup/system/rate-limit.conf"
  sudo touch "$backup/system/rate-limit.conf.present"
else
  sudo touch "$backup/system/rate-limit.conf.absent"
fi
if sudo test -f /etc/logrotate.d/repcoach-ai; then
  sudo cp -a /etc/logrotate.d/repcoach-ai "$backup/system/logrotate"
  sudo touch "$backup/system/logrotate.present"
else
  sudo touch "$backup/system/logrotate.absent"
fi
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

# systemd can report active before Python has bound port 8787. Wait for the
# actual local health route instead of treating that short startup window as a
# failed deployment.
backend_ready=0
for _ in $(seq 1 20); do
  if sudo systemctl is-active --quiet repcoach-backend \
    && curl -fsS --max-time 1 http://127.0.0.1:8787/health \
      | grep -Fq '"status": "ok"'; then
    backend_ready=1
    break
  fi
  sleep 0.5
done
if [[ "$backend_ready" -ne 1 ]]; then
  echo "backend did not become healthy within 10 seconds" >&2
  exit 4
fi

sudo ss -ltn | grep -F '127.0.0.1:8787' >/dev/null

# Capture nginx -T once. With pipefail enabled, piping nginx -T directly into
# grep can produce a false failure when grep exits early and nginx receives
# SIGPIPE.
nginx_dump="$(sudo nginx -T 2>/dev/null)"
grep -Fq 'client_max_body_size 16k;' <<<"$nginx_dump"
grep -Fq 'limit_req zone=repcoach_api' <<<"$nginx_dump"
grep -Fq 'proxy_read_timeout 22s;' <<<"$nginx_dump"
grep -Fq 'location = /privacy-policy.html' <<<"$nginx_dump"
grep -Fq 'location = /health' <<<"$nginx_dump"
grep -Fq 'location = /ready' <<<"$nginx_dump"

completed=1
trap - EXIT
printf 'BACKUP_PATH=%s\n' "$backup"
