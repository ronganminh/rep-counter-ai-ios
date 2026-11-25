#!/usr/bin/env bash
# web_apply.sh — publish the RepCoach AI web pages from this checkout to the VPS.
#
# Installs, from the commit that is checked out:
#   - backend/server.py and backend/ai_provider.py (the page routes live in
#     server.py; /delete-account.html needs it), then restarts repcoach-backend;
#   - backend/static/{privacy-policy,support,terms,delete-account}.html;
#   - backend/deploy/repcoach-ai.nginx as the nginx site, then reloads nginx.
# It does not touch .env, the systemd unit, rate limits or log rotation
# (b7_apply.sh does those).
#
# Safety:
#   - EXPECTED_SHA is required; the checkout must be at that commit, clean.
#   - Everything it replaces is copied to BACKUP_PATH first
#     (BACKUP_ROOT/<UTC time>), printed at the start and end.
#   - On any error after the backup it restores the backup automatically.
#   - It never prints secrets.
#
# Usage (see backend/deploy/README.md):
#   EXPECTED_SHA=<sha> bash rep-counter-ai-main/backend/deploy/web_apply.sh
#
# Overridable with environment variables:
#   REPO_DIR    repo clone (default: the clone this script is in)
#   APP_DIR     backend install dir (default: /home/nduythanh/apps/repcoach-backend,
#               the WorkingDirectory of repcoach-backend.service)
#   NGINX_SITE  nginx site file (default: /etc/nginx/sites-available/repcoach-ai;
#               check with: ls -l /etc/nginx/sites-enabled/)
#   PUBLIC_URL  public base URL checked at the end
#               (default: https://repcoach-ai.duckdns.org)
#   BACKUP_ROOT where backups go (default: /var/backups/repcoach-web)
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$(cd "$script_dir/../../.." && pwd)}"
APP_DIR="${APP_DIR:-/home/nduythanh/apps/repcoach-backend}"
NGINX_SITE="${NGINX_SITE:-/etc/nginx/sites-available/repcoach-ai}"
PUBLIC_URL="${PUBLIC_URL:-https://repcoach-ai.duckdns.org}"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/repcoach-web}"
EXPECTED_SHA="${EXPECTED_SHA:-}"

SRC="$REPO_DIR/rep-counter-ai-main/backend"
PAGES=(privacy-policy.html support.html terms.html delete-account.html)

fail() { echo "web_apply: $*" >&2; exit 2; }

# 1. The checkout is the commit the owner approved, with no local edits.
[[ "$EXPECTED_SHA" =~ ^[0-9a-f]{7,40}$ ]] \
  || fail "set EXPECTED_SHA to the commit to deploy (7-40 hex characters)"
sha="$(git -C "$REPO_DIR" rev-parse HEAD)"
[[ "$sha" == "$EXPECTED_SHA"* ]] \
  || fail "checkout is at $sha, not $EXPECTED_SHA (git checkout --detach $EXPECTED_SHA)"
[[ -z "$(git -C "$REPO_DIR" status --porcelain -- rep-counter-ai-main/backend)" ]] \
  || fail "local changes under rep-counter-ai-main/backend; deploy only committed files"
echo "Deploying web pages from $sha"

# 2. Checks before anything is changed.
[[ -f "$APP_DIR/.env" ]] || fail "$APP_DIR/.env missing (set APP_DIR)"
sudo test -f "$NGINX_SITE" || fail "$NGINX_SITE not found (set NGINX_SITE)"
for page in "${PAGES[@]}"; do
  [[ -s "$SRC/static/$page" ]] || fail "missing $SRC/static/$page"
done
python3 -m py_compile "$SRC/server.py" "$SRC/ai_provider.py"
grep -q 'DELETE_ACCOUNT_PAGE_PATH' "$SRC/server.py" || fail "server.py has no delete-account route"
grep -q 'location = /delete-account.html' "$SRC/deploy/repcoach-ai.nginx" \
  || fail "nginx site has no delete-account location"
for cmd in nginx systemctl curl; do
  command -v "$cmd" >/dev/null 2>&1 || sudo sh -c "command -v $cmd" >/dev/null 2>&1 \
    || fail "missing command: $cmd"
done

# 3. Backup of everything this script replaces.
BACKUP_PATH="$BACKUP_ROOT/$(date -u +%Y%m%dT%H%M%SZ)"
sudo install -d -m 0700 "$BACKUP_PATH"
for f in server.py ai_provider.py; do
  if [[ -f "$APP_DIR/$f" ]]; then sudo cp -a "$APP_DIR/$f" "$BACKUP_PATH/$f"; fi
done
if [[ -d "$APP_DIR/static" ]]; then sudo cp -a "$APP_DIR/static" "$BACKUP_PATH/static"; fi
sudo cp -a "$NGINX_SITE" "$BACKUP_PATH/nginx-site"
echo "$sha" | sudo tee "$BACKUP_PATH/DEPLOYED_SHA" >/dev/null
echo "BACKUP_PATH=$BACKUP_PATH"

restore_backup() {
  trap - ERR
  set +e
  echo "web_apply: FAILED, restoring $BACKUP_PATH" >&2
  for f in server.py ai_provider.py; do
    if sudo test -f "$BACKUP_PATH/$f"; then sudo cp -a "$BACKUP_PATH/$f" "$APP_DIR/$f"; fi
  done
  if sudo test -d "$BACKUP_PATH/static"; then
    sudo rm -rf "$APP_DIR/static"
    sudo cp -a "$BACKUP_PATH/static" "$APP_DIR/static"
  fi
  sudo cp -a "$BACKUP_PATH/nginx-site" "$NGINX_SITE"
  if sudo nginx -t; then sudo systemctl reload nginx; fi
  sudo systemctl restart repcoach-backend || true
  echo "web_apply: restored from $BACKUP_PATH" >&2
  exit 1
}
trap restore_backup ERR

# 4. Install.
install -d -m 0755 "$APP_DIR/static"
install -m 0644 "$SRC/server.py" "$APP_DIR/server.py"
install -m 0644 "$SRC/ai_provider.py" "$APP_DIR/ai_provider.py"
for page in "${PAGES[@]}"; do
  install -m 0644 "$SRC/static/$page" "$APP_DIR/static/$page"
done
sudo install -m 0644 "$SRC/deploy/repcoach-ai.nginx" "$NGINX_SITE"

# 5. Validate, restart the backend, reload nginx.
sudo nginx -t
sudo systemctl restart repcoach-backend
healthy=0
for _ in $(seq 1 20); do
  # Capture first: with pipefail, curl | grep -q can fail on SIGPIPE.
  health="$(curl -fsS --max-time 1 http://127.0.0.1:8787/health 2>/dev/null || true)"
  if grep -Fq '"status": "ok"' <<<"$health"; then
    healthy=1
    break
  fi
  sleep 0.5
done
[[ "$healthy" -eq 1 ]] || { echo "web_apply: backend not healthy after 10 s" >&2; false; }
sudo systemctl reload nginx

# 6. Public checks: each page answers 200 with its v2 content.
check_page() {
  local body
  body="$(curl -fsS --max-time 10 "$PUBLIC_URL/$1")"
  grep -Fq "$2" <<<"$body"
  echo "OK  $PUBLIC_URL/$1"
}
check_page privacy-policy.html "delete-account.html"
check_page support.html "delete-account.html"
check_page delete-account.html "RepCoach AI account deletion request"
check_page terms.html "RepCoach"

trap - ERR
echo "WEB_DEPLOY=PASS sha=$sha"
echo "BACKUP_PATH=$BACKUP_PATH"
