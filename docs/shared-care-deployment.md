# Shared Care deployment on Raspberry Pi

This is the Issue #159 deployment layout for a 64-bit Raspberry Pi OS host.
The server and HTTPS gateway run as ARM64 containers. The server owns one
collection SQLite database and one account/session SQLite database. Media is
stored in the collection database, so both files must be kept together.

**Current scope:** The HTTPS gateway currently serves a readiness page. The
existing Flutter Web application still uses a browser-local database; it is
not a shared client. Issue #160 will replace the readiness page with the
API-backed Web interface. Do not direct caregivers to the standalone Web app
and expect their changes to be shared. The deployment cannot meet the shared
browser workflow acceptance criteria until #160 is integrated and tested.

## Host and network preparation

Use a Raspberry Pi running 64-bit Raspberry Pi OS, with Docker Engine and the
Docker Compose plugin installed. Reserve a stable LAN address for the Pi in
the router or configure a static address. Give it a hostname that every
caregiver device resolves to that address; `terramanager.home.arpa` is an
example. Do not forward port 443 on the router or publish this host to the
internet. Limit inbound port 443 to the trusted LAN in the host/router
firewall. No Android application permission or external account is needed.

Obtain a TLS certificate and private key for the exact hostname or IP used by
clients. The certificate needs a matching Subject Alternative Name. A private
local CA is suitable: install **only its public root certificate** in the
client trust stores. Do not distribute the CA private key. Copy the server
certificate chain to `deploy/certs/server.crt` and its key to
`deploy/certs/server.key` on the Pi. The gateway reads these files from a
read-only bind mount. It does not request public certificates. Never place
private keys, passwords or database files in Git or a container image.

From the repository root on the Pi:

```sh
cd deploy
cp .env.example .env
mkdir -p data certs backups
sudo chown 10001:10001 data
chmod 700 data certs backups
```

Edit `.env`: set `TM_LAN_BIND_IP` to the Pi's LAN address, `TM_HOST` to the
certificate hostname (or the same IP if the certificate covers that IP), and
`TM_STACK_VERSION` to a local image tag for this source revision. Put the
certificate and key in `certs/` and make the key readable only by the host
administrator. These paths are ignored by Git. The database directory must
remain owned by numeric user 10001, which runs the server container.

Check the interpolated configuration before the first start:

```sh
docker compose config
docker compose build
docker compose run --rm --no-deps --entrypoint /opt/admin/bin/create_admin server
docker compose up -d --no-build
docker compose ps
```

The administrator setup is interactive and accepts a password of at least 12
characters without echoing it. It cannot run again after an account exists.
Do not pass passwords as command-line arguments or environment variables.
Builds need access to the selected base images and Dart packages; routine
operation does not. The server has no published port. Only the gateway binds
`TM_LAN_BIND_IP:443` and forwards `/api/*` inside the Compose network.

Open `https://<TM_HOST>/` from a second LAN device. It should show the
readiness page without a browser certificate warning after the local CA is
trusted. `https://<TM_HOST>/api/v1/health` should return `{"status":"ok"}`;
it contains no collection or account data. An unauthenticated request to
`/api/v1/boxes` should return `401`. Login and all record access use the
HTTPS origin. The present readiness page does not yet provide a login form;
the shared browser client is Issue #160. To inspect API operations, see
[Shared Care API](shared-care-api.md). Test again with WAN access disabled
while keeping the LAN active to verify offline operation.

## Persistence and backups

`deploy/data` is a host bind mount, independent of the image and container
lifetime. It holds `collection.sqlite` (including pictures) and
`accounts.sqlite` (including local accounts and sessions), plus SQLite WAL
files while the server runs. Do not mount it from a network share or start
multiple server replicas against the same files. A portable collection backup
does not include accounts.

Take a consistent volume snapshot by stopping the server before copying the
directory. From `deploy/`:

```sh
docker compose stop server
tar -czf backups/terramanager-$(date +%Y%m%d-%H%M%S).tar.gz data
docker compose start server
docker compose ps
```

Keep backup archives on separately protected storage. A backup of the live
database without stopping the server can omit writes still in SQLite's WAL.
Protect the archives like the original database: they contain pictures,
animal records, account hashes and active sessions. Verify a backup by
restoring it to an isolated test installation, not over the running server.

## Update and rollback

Before updating, keep the old image tags available and make a stopped-server
volume backup. Then fetch the desired source revision, choose a new
`TM_STACK_VERSION` in `.env`, and run:

```sh
docker compose config
docker compose build
docker compose up -d --no-build
docker compose ps
```

Check HTTPS, health, login and a representative collection request. Image
replacement does not erase the bind-mounted data. On an unsuccessful update,
stop the stack, switch `.env` and source files back to the old revision, and
restore the **matching pre-update data snapshot** before starting the old
images. A newer database schema may not be readable by old code. Restore
both SQLite files together and retain the failed-upgrade data separately for
diagnosis. When the old images are no longer cached, restore them from an
operator-kept image archive before restarting.

Certificate renewal is an operator action: replace the two files in
`deploy/certs/` with a new matching pair and restart the `web` service. Keep
the hostname and client trust configuration aligned. No runtime cloud
service, analytics endpoint or port forwarding is part of this stack.
