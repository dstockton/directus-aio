ARG DIRECTUS_VERSION=latest

FROM directus/directus:${DIRECTUS_VERSION}

USER root

RUN apk update && apk upgrade && \
    apk add --no-cache \
      postgresql \
      postgresql-client \
      bash && \
    mkdir -p /persistent /run/postgresql /home/node && \
    chown node:node /persistent /run/postgresql /home/node && \
    rm -rf /var/cache/apk/*

ENV DB_CLIENT="pg" \
    DB_HOST="127.0.0.1" \
    DB_PORT="5432" \
    DB_USER="directus" \
    DB_PASSWORD="directus" \
    DB_DATABASE="directus" \
    STORAGE_LOCAL_ROOT="/persistent/uploads" \
    HASH_MEMORY_COST="8192" \
    HASH_TIME_COST="2" \
    HASH_PARALLELISM="1"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Build fingerprint — changes when Directus version, entrypoint, or config changes
RUN sha256sum /directus/package.json /entrypoint.sh | sha256sum | cut -c1-16 > /directus/.build-hash

USER node

EXPOSE 8055

ENTRYPOINT ["/entrypoint.sh"]
CMD []
