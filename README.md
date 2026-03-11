# directus-aio

All-in-one Directus Docker image with embedded PostgreSQL and MinIO. For simple demo/dev hosting.

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
- **PostgreSQL** — database (data stored at `/persistent/pgdata`)
- **MinIO** — S3-compatible object storage (data at `/persistent/minio`, console at port 9001)

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
| STORAGE_LOCATIONS | s3 |
| STORAGE_S3_DRIVER | s3 |
| STORAGE_S3_KEY | minioadmin |
| STORAGE_S3_SECRET | minioadmin |
| STORAGE_S3_BUCKET | directus |
| STORAGE_S3_ENDPOINT | http://127.0.0.1:9000 |
| STORAGE_S3_REGION | us-east-1 |
| STORAGE_S3_FORCE_PATH_STYLE | true |

All standard Directus environment variables are supported.

## Image Tags

Tags mirror upstream `directus/directus` semver releases starting from 11.16.0. Checked hourly.
