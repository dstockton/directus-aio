#!/bin/bash
set -euo pipefail

MINIO_PID=""
cleanup() {
  pg_ctl -D /persistent/pgdata -w stop 2>/dev/null || true
  [ -n "$MINIO_PID" ] && kill "$MINIO_PID" 2>/dev/null || true
}
trap cleanup EXIT SIGTERM SIGINT

# --- Persistence check ---
if grep -q ' /persistent ' /proc/self/mountinfo 2>/dev/null; then
  : # mounted, good
elif [ "$(stat -c '%d' /)" != "$(stat -c '%d' /persistent)" ]; then
  : # different device, good
else
  echo "ERROR: /persistent is not a mounted volume. Data would be lost on container restart."
  echo "Run with: docker run -v <volume-or-path>:/persistent ..."
  exit 1
fi

PGDATA="/persistent/pgdata"

# --- Init Postgres if needed ---
if [ ! -d "$PGDATA" ]; then
  echo "Initializing PostgreSQL database..."
  mkdir -p "$PGDATA"
  initdb -D "$PGDATA" --auth=trust
  echo "host all all 127.0.0.1/32 trust" >> "$PGDATA/pg_hba.conf"

  pg_ctl -D "$PGDATA" -o "-p 5432" -w start
  createuser -h 127.0.0.1 -p 5432 directus
  createdb -h 127.0.0.1 -p 5432 -O directus directus
  pg_ctl -D "$PGDATA" -w stop
fi

# --- Start Postgres ---
echo "Starting PostgreSQL..."
pg_ctl -D "$PGDATA" -o "-p 5432" -w start
echo "PostgreSQL is ready."

# --- Start MinIO ---
echo "Starting MinIO..."
mkdir -p /persistent/minio
MINIO_ROOT_USER=minioadmin MINIO_ROOT_PASSWORD=minioadmin \
  minio server /persistent/minio --console-address ":9001" &
MINIO_PID=$!

for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:9000/minio/health/live >/dev/null 2>&1; then
    echo "MinIO is ready."
    break
  fi
  [ "$i" -eq 30 ] && { echo "ERROR: MinIO failed to start."; exit 1; }
  sleep 1
done

# Create bucket if needed
mc alias set local http://127.0.0.1:9000 minioadmin minioadmin --quiet
mc mb --ignore-existing local/directus --quiet

# --- Start Directus (foreground) ---
echo "Starting Directus..."
cd /directus
node cli.js bootstrap
exec pm2-runtime start ecosystem.config.cjs
