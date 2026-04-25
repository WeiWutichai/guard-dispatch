#!/usr/bin/env bash
# reset-staging.sh — Wipe staging data so the team can register fresh
# accounts without colliding with old ones. Keeps admin users on web admin.
#
# What it touches (all *inside* the Docker network on the VPS):
#   1. PostgreSQL — runs reset-staging.sql (admin users + service_rates kept)
#   2. Redis cache + pubsub — FLUSHDB on both (clears OTP/captcha/jti/cache)
#   3. MinIO    — removes uploaded files under guard-dispatch-files/
#
# Will REFUSE to run unless you set STAGING_RESET_OK=yes. This is a footgun.
#
# Usage on VPS (as root, in /root/guard-dispatch):
#   STAGING_RESET_OK=yes bash scripts/reset-staging.sh

set -euo pipefail

if [[ "${STAGING_RESET_OK:-}" != "yes" ]]; then
  cat >&2 <<EOF
==> Refusing to run.
    This script wipes staging data. Re-run with:
        STAGING_RESET_OK=yes bash scripts/reset-staging.sh
EOF
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL_FILE="$ROOT/scripts/reset-staging.sql"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "==> Missing $SQL_FILE" >&2
  exit 1
fi

# Containers (override via env if your compose names differ).
DB_CONTAINER="${DB_CONTAINER:-postgres-db}"
REDIS_CACHE_CONTAINER="${REDIS_CACHE_CONTAINER:-redis-cache}"
REDIS_PUBSUB_CONTAINER="${REDIS_PUBSUB_CONTAINER:-redis-pubsub}"
MINIO_CONTAINER="${MINIO_CONTAINER:-minio}"

# Postgres user/db names. Prefer the same env var names docker-compose
# uses (POSTGRES_USER / POSTGRES_DB from .env) so this works out of the
# box; allow DB_USER / DB_NAME overrides for ad-hoc runs.
DB_USER="${DB_USER:-${POSTGRES_USER:?POSTGRES_USER must be set (in .env or env)}}"
DB_NAME="${DB_NAME:-${POSTGRES_DB:-guard_dispatch_db}}"

# Pull Redis password from the .env file the compose stack already uses.
# Falls back to env var if the file's not there.
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
REDIS_PASSWORD="${REDIS_PASSWORD:?REDIS_PASSWORD must be set (in .env or env)}"

S3_BUCKET="${S3_BUCKET:-guard-dispatch-files}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:?S3_ACCESS_KEY must be set}"
S3_SECRET_KEY="${S3_SECRET_KEY:?S3_SECRET_KEY must be set}"

echo "==> 1/3  Postgres — running reset-staging.sql"
docker compose exec -T "$DB_CONTAINER" \
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
  < "$SQL_FILE"

echo
echo "==> 2/3  Redis — FLUSHDB cache + pubsub"
docker compose exec -T "$REDIS_CACHE_CONTAINER" \
  redis-cli -a "$REDIS_PASSWORD" FLUSHDB
docker compose exec -T "$REDIS_PUBSUB_CONTAINER" \
  redis-cli -a "$REDIS_PASSWORD" FLUSHDB

echo
echo "==> 3/3  MinIO — clearing uploaded files under guard-dispatch-files/"
# Use the bundled `mc` inside the minio image to avoid needing it on the host.
docker compose exec -T "$MINIO_CONTAINER" sh -c "
  mc alias set local http://localhost:9000 '$S3_ACCESS_KEY' '$S3_SECRET_KEY' >/dev/null
  for prefix in profiles chat progress-reports; do
    if mc ls local/$S3_BUCKET/\$prefix/ >/dev/null 2>&1; then
      echo \"   - rm local/$S3_BUCKET/\$prefix/ (recursive)\"
      mc rm --recursive --force local/$S3_BUCKET/\$prefix/ >/dev/null 2>&1 || true
    fi
  done
"

echo
echo "==> Done."
echo "   - Admin web users + booking.service_rates kept."
echo "   - Everything else wiped."
echo "   - Admin sessions are still valid (Postgres auth.sessions untouched)."
echo "     If you flushed Redis, JWT revocation list reset — that's expected."
