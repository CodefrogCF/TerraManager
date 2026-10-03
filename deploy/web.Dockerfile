FROM caddy:2.11.4-alpine

RUN apk upgrade --no-cache

COPY deploy/Caddyfile /etc/caddy/Caddyfile
COPY deploy/web-dist/ /srv/web/

RUN test -f /srv/web/index.html \
    && test -f /srv/web/assets/fonts/fallback/Roboto-Regular.ttf