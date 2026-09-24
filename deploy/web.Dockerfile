FROM --platform=linux/arm64 caddy:2.10.2-alpine
COPY deploy/Caddyfile /etc/caddy/Caddyfile
COPY deploy/web-dist/ /srv/web/
RUN test -f /srv/web/index.html \
    && test -f /srv/web/assets/fonts/fallback/Roboto-Regular.ttf
