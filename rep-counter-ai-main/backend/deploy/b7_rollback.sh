#!/usr/bin/env bash
set -euo pipefail

backup="${1:?backup path required}"
app_dir="${2:-/home/nduythanh/apps/repcoach-backend}"

case "$backup" in
  /var/backups/repcoach-b7/*) ;;
  *) echo "refusing unexpected backup path" >&2; exit 2 ;;
esac

sudo test -d "$backup"

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

sudo systemctl daemon-reload
sudo nginx -t
sudo systemctl start repcoach-backend
sudo systemctl reload nginx

sudo systemctl is-active --quiet repcoach-backend
echo "ROLLBACK_PASS backup=$backup"
