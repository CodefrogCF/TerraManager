FROM --platform=linux/arm64 caddy:2.10.2-alpine
COPY deploy/Caddyfile /etc/caddy/Caddyfile
COPY deploy/landing/index.html /srv/web/index.html
