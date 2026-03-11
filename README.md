# directus-aio

All-in-one Directus Docker image with embedded PostgreSQL. For simple demo/dev hosting.

## Quick Start

```bash
docker run -d \
  -p 8055:8055 \
  -v directus-data:/persistent \
  -e SECRET=change-me \
  -e ADMIN_EMAIL=admin@example.com \
  -e ADMIN_PASSWORD=admin \
  ghcr.io/dstockton/directus-aio:latest
```

## What's Included

- **Directus** — headless CMS (foreground process)
- **PostgreSQL** — database (data at `/persistent/pgdata`)
- File uploads stored at `/persistent/uploads`

A `-v` mount on `/persistent` is **required** — the container will refuse to start without one.

## Resource Tuning

Memory is auto-allocated at startup based on container limits (~60% Node, ~35% Postgres, ~5% OS). Works well from 256MB up.

## Default Config

| Variable | Default |
|---|---|
| DB_CLIENT | pg |
| DB_HOST | 127.0.0.1 |
| DB_PORT | 5432 |
| DB_USER | directus |
| DB_PASSWORD | directus |
| DB_DATABASE | directus |
| STORAGE_LOCAL_ROOT | /persistent/uploads |

All standard Directus environment variables are supported.

## Image Tags

Tags mirror upstream `directus/directus` semver releases starting from 11.16.0. Checked hourly.
