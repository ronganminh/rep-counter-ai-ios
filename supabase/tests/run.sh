#!/usr/bin/env bash
# Applies every migration to a fresh database on a plain Postgres (with the
# Supabase stub) and runs the SQL tests. No Supabase project, no secrets.
#
#   PGHOST=… PGPORT=… PGUSER=postgres supabase/tests/run.sh
#
# CI runs it against a postgres:16 service (.github/workflows/supabase-functions.yml).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
db="${TEST_DB:-repcoach_sql_test}"

psql_admin=(psql -X -q -v ON_ERROR_STOP=1 -d postgres)
"${psql_admin[@]}" -c "drop database if exists $db" -c "create database $db"

run() {
  echo "-- $1"
  CONTRACTS_DIR="$root/contracts" FUNCTIONS_DIR="$root/functions" psql -X -q -v ON_ERROR_STOP=1 -d "$db" -f "$1"
}

run "$here/supabase_stub.sql"
for f in "$root"/migrations/*.sql; do run "$f"; done
for f in "$here"/*.test.sql; do run "$f"; done

echo "SQL tests passed"
