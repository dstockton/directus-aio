#!/bin/bash
set -euo pipefail

cleanup() {
  pg_ctl -D /persistent/pgdata -w stop 2>/dev/null || true
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

# --- Detect available memory and set resource limits ---
# Target: ~60% node, ~35% postgres, ~5% OS overhead
# Check cgroup limit first (container), fall back to host memory
CGROUP_LIMIT=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo "max")
if [ "$CGROUP_LIMIT" != "max" ] && [ "$CGROUP_LIMIT" -gt 0 ] 2>/dev/null; then
  TOTAL_MEM_MB=$((CGROUP_LIMIT / 1024 / 1024))
else
  TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
fi

# Minimum 256MB assumed; cap calculations to avoid nonsense on tiny containers
if [ "$TOTAL_MEM_MB" -lt 256 ]; then
  TOTAL_MEM_MB=256
fi

NODE_MEM_MB=$((TOTAL_MEM_MB * 60 / 100))
PG_SHARED_BUFFERS_MB=$((TOTAL_MEM_MB * 35 / 100 / 4))  # shared_buffers ~25% of PG allocation
PG_WORK_MEM_MB=$((TOTAL_MEM_MB * 35 / 100 / 10))        # work_mem ~10% of PG allocation
PG_MAINT_WORK_MEM_MB=$((TOTAL_MEM_MB * 35 / 100 / 5))   # maintenance_work_mem ~20% of PG allocation
PG_EFF_CACHE_MB=$((TOTAL_MEM_MB * 35 / 100 * 3 / 4))    # effective_cache_size ~75% of PG allocation

# Floor values
[ "$PG_SHARED_BUFFERS_MB" -lt 16 ] && PG_SHARED_BUFFERS_MB=16
[ "$PG_WORK_MEM_MB" -lt 2 ] && PG_WORK_MEM_MB=2
[ "$PG_MAINT_WORK_MEM_MB" -lt 8 ] && PG_MAINT_WORK_MEM_MB=8
[ "$PG_EFF_CACHE_MB" -lt 32 ] && PG_EFF_CACHE_MB=32
[ "$NODE_MEM_MB" -lt 128 ] && NODE_MEM_MB=128

echo "Memory: ${TOTAL_MEM_MB}MB total -> Node ${NODE_MEM_MB}MB, PG shared_buffers ${PG_SHARED_BUFFERS_MB}MB, work_mem ${PG_WORK_MEM_MB}MB"

export NODE_OPTIONS="--max-old-space-size=${NODE_MEM_MB}"

# --- Ensure uploads directory ---
mkdir -p /persistent/uploads

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

# --- Write Postgres memory config ---
cat > "$PGDATA/aio-tuning.conf" <<PGCONF
shared_buffers = ${PG_SHARED_BUFFERS_MB}MB
work_mem = ${PG_WORK_MEM_MB}MB
maintenance_work_mem = ${PG_MAINT_WORK_MEM_MB}MB
effective_cache_size = ${PG_EFF_CACHE_MB}MB
max_connections = 20
PGCONF

# Include our tuning config if not already included
if ! grep -q 'aio-tuning.conf' "$PGDATA/postgresql.conf"; then
  echo "include = 'aio-tuning.conf'" >> "$PGDATA/postgresql.conf"
fi

# --- Start Postgres ---
echo "Starting PostgreSQL..."
pg_ctl -D "$PGDATA" -o "-p 5432" -w start
echo "PostgreSQL is ready."

# --- Start Directus ---
echo "Starting Directus..."
cd /directus

# Skip bootstrap on warm restarts when version hasn't changed
CURRENT_VERSION=$(node -e "console.log(require('./package.json').version)" 2>/dev/null || echo "unknown")
MARKER="/persistent/.bootstrapped-version"

if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$CURRENT_VERSION" ]; then
  echo "Skipping bootstrap (already ran for v${CURRENT_VERSION})"
else
  node cli.js bootstrap
  echo "$CURRENT_VERSION" > "$MARKER"
fi

exec node cli.js start
