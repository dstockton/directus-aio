ARG DIRECTUS_VERSION=latest

FROM directus/directus:${DIRECTUS_VERSION}

USER root

# Update/upgrade all packages and install Postgres + MinIO deps
RUN apk update && apk upgrade && \
    apk add --no-cache \
      postgresql \
      postgresql-client \
      postgresql-contrib \
      bash \
      curl && \
    mkdir -p /persistent /run/postgresql /home/node && \
    chown node:node /persistent /run/postgresql /home/node && \
    rm -rf /var/cache/apk/*

# Install MinIO server and client
ARG TARGETARCH
RUN wget -q https://dl.min.io/server/minio/release/linux-${TARGETARCH}/minio -O /usr/local/bin/minio && \
    wget -q https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc -O /usr/local/bin/mc && \
    chmod +x /usr/local/bin/minio /usr/local/bin/mc

# Default environment variables
ENV DB_CLIENT="pg" \
    DB_HOST="127.0.0.1" \
    DB_PORT="5432" \
    DB_USER="directus" \
    DB_PASSWORD="directus" \
    DB_DATABASE="directus" \
    STORAGE_LOCATIONS="s3" \
    STORAGE_S3_DRIVER="s3" \
    STORAGE_S3_KEY="minioadmin" \
    STORAGE_S3_SECRET="minioadmin" \
    STORAGE_S3_BUCKET="directus" \
    STORAGE_S3_ENDPOINT="http://127.0.0.1:9000" \
    STORAGE_S3_REGION="us-east-1" \
    STORAGE_S3_FORCE_PATH_STYLE="true"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node

EXPOSE 8055

ENTRYPOINT ["/entrypoint.sh"]
CMD []
