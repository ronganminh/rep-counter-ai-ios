#!/usr/bin/env bash
set -euo pipefail

backup="${1:?backup path required}"
app_dir="${2:-/home/nduythanh/apps/repcoach-backend}"

case "$backup" in
  /var/backups/repcoach-b7/*) ;;
  *) echo "refusing unexpected backup path" >&2; exit 2 ;;
esac

sudo -n true
sudo test -d "$backup"

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

sudo systemctl daemon-reload
sudo nginx -t
sudo systemctl start repcoach-backend
sudo systemctl reload nginx

sudo systemctl is-active --quiet repcoach-backend
echo "ROLLBACK_PASS backup=$backup"
