#!/bin/bash
set -euo pipefail

cleanup() {
  su-exec postgres pg_ctl -D /persistent/pgdata -w stop 2>/dev/null || true
  valkey-cli shutdown nosave 2>/dev/null || true
}
trap cleanup EXIT SIGTERM SIGINT

# --- Persistence check ---
# Fail if /persistent is not a real mount point (check mountinfo, fall back to device ID comparison)
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

# Ensure subdirectory ownership
mkdir -p /persistent/valkey
chown node:node /persistent/valkey

# Postgres needs a socket directory
mkdir -p /run/postgresql
chown postgres:postgres /run/postgresql

# --- Init Postgres if needed ---
if [ ! -d "$PGDATA" ]; then
  echo "Initializing PostgreSQL database..."
  mkdir -p "$PGDATA"
  chown postgres:postgres "$PGDATA"
  su-exec postgres initdb -D "$PGDATA" --auth=trust
  echo "host all all 127.0.0.1/32 trust" >> "$PGDATA/pg_hba.conf"

  # Start temporarily to create user/database
  su-exec postgres pg_ctl -D "$PGDATA" -o "-p 5432" -w start
  su-exec postgres createuser -h 127.0.0.1 -p 5432 directus
  su-exec postgres createdb -h 127.0.0.1 -p 5432 -O directus directus
  su-exec postgres pg_ctl -D "$PGDATA" -w stop
fi

# --- Start Postgres ---
echo "Starting PostgreSQL..."
su-exec postgres pg_ctl -D "$PGDATA" -o "-p 5432" -w start
echo "PostgreSQL is ready."

# --- Start Valkey ---
echo "Starting Valkey..."
su-exec node valkey-server --daemonize yes --dir /persistent/valkey

for i in $(seq 1 30); do
  if valkey-cli ping 2>/dev/null | grep -q PONG; then
    echo "Valkey is ready."
    break
  fi
  [ "$i" -eq 30 ] && { echo "ERROR: Valkey failed to start."; exit 1; }
  sleep 1
done

# --- Start Directus (foreground, as node user) ---
echo "Starting Directus..."
cd /directus
su-exec node node cli.js bootstrap
exec su-exec node pm2-runtime start ecosystem.config.cjs
