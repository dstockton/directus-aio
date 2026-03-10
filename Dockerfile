ARG DIRECTUS_VERSION=11.16.0

FROM directus/directus:${DIRECTUS_VERSION}

USER root

# Update/upgrade all packages and install Postgres + Valkey + su-exec
RUN apk update && apk upgrade && \
    apk add --no-cache \
      postgresql \
      postgresql-client \
      postgresql-contrib \
      valkey \
      bash \
      su-exec && \
    mkdir -p /persistent && \
    mkdir -p /home/node && \
    chown node:node /home/node

VOLUME /persistent

# Default environment variables
ENV DB_CLIENT="pg" \
    DB_HOST="127.0.0.1" \
    DB_PORT="5432" \
    DB_USER="directus" \
    DB_PASSWORD="directus" \
    DB_DATABASE="directus" \
    CACHE_ENABLED="true" \
    CACHE_AUTO_PURGE="true" \
    CACHE_STORE="redis" \
    REDIS="redis://127.0.0.1:6379"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Entrypoint runs as root; drops privileges per-process via su-exec
ENTRYPOINT ["/entrypoint.sh"]
CMD []
