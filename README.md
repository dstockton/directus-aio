# directus-aio

All-in-one Directus Docker image with embedded PostgreSQL and Valkey. For simple demo/dev hosting.

## Quick Start

```bash
docker run -d \
  -p 8055:8055 \
  -v directus-data:/persistent \
  -e SECRET=change-me \
  -e ADMIN_EMAIL=admin@example.com \
  -e ADMIN_PASSWORD=admin \
  ghcr.io/dstockton/directus-aio:11.16.0
```

## What's Included

- **Directus** — headless CMS (foreground process)
- **PostgreSQL** — database (data stored at `/persistent/pgdata`)
- **Valkey** — cache (Redis-compatible, data at `/persistent/valkey`)

A `-v` mount on `/persistent` is **required** — the container will refuse to start without one.

## Default Config

| Variable | Default |
|---|---|
| DB_CLIENT | pg |
| DB_HOST | 127.0.0.1 |
| DB_PORT | 5432 |
| DB_USER | directus |
| DB_PASSWORD | directus |
| DB_DATABASE | directus |
| CACHE_ENABLED | true |
| CACHE_AUTO_PURGE | true |
| CACHE_STORE | redis |
| REDIS | redis://127.0.0.1:6379 |

All standard Directus environment variables are supported.

## Image Tags

Tags mirror upstream `directus/directus` semver releases starting from 11.16.0. Checked hourly.
