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
    STORAGE_LOCAL_ROOT="/persistent/uploads"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node

EXPOSE 8055

ENTRYPOINT ["/entrypoint.sh"]
CMD []
