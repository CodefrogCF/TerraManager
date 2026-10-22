# Shared Care deployment on Raspberry Pi

Shared Care runs a Dart API and Caddy HTTPS gateway as ARM64 containers on a
64-bit Raspberry Pi OS host with Docker/Compose. The gateway serves the dedicated
`lib/main_shared.dart` Web build. Standalone Android/Web collections stay separate.
Only the gateway exposes LAN port 443; keep the API inside the Compose network.

## Prepare host and trusted HTTPS

1. Reserve a stable LAN address and resolvable hostname. Keep this service on a
   trusted LAN; do not configure public port forwarding.
2. Obtain a certificate with a matching hostname/IP SAN. Put its chain/key in
   `deploy/certs/server.crt` and `deploy/certs/server.key`. Protect the private
   key; never commit it or distribute the CA private key.
3. Install only the public local CA on clients that need it. Check the exact
   HTTPS address without certificate warnings; a bypass is not trusted HTTPS.

From the repository root on the Pi:

```sh
cd deploy
cp .env.example .env
mkdir -p data certs backups
sudo chown 10001:10001 data
chmod 700 data certs backups
```

Set `TM_LAN_BIND_IP`, `TM_HOST` and a revision-specific `TM_STACK_VERSION` in
`.env`. The server runs as UID 10001. Keep credentials, `.env`, live databases,
backups and private keys outside Git/images; generated runtime paths are ignored.

## Build and start

On the development machine, build the Shared Care client with local fonts:

```sh
flutter pub get
flutter build web --release --target lib/main_shared.dart --no-web-resources-cdn
tar -C build/web -czf terramanager-shared-web.tar.gz .
scp terramanager-shared-web.tar.gz <pi-user>@<pi-host>:~/TerraManager/deploy/
```

On the Pi, from `deploy/`:

```sh
mkdir -p web-dist
tar -xzf terramanager-shared-web.tar.gz -C web-dist
test -f web-dist/index.html
test -f web-dist/assets/fonts/fallback/Roboto-Regular.ttf
docker compose config
docker compose build
docker compose run --rm --no-deps --entrypoint /opt/admin/bin/create_admin server
docker compose up -d --no-build
docker compose ps
```

Bootstrap prompts interactively for the first administrator; there is no default
password. It requires at least 12 characters and cannot be rerun after accounts
exist. Routine operation needs no external account or cloud service; building
needs package/base-image access. The bundled-font check prevents a LAN-only UI
without text. Transfer/redeploy the complete matching Web build with server updates.

## Commissioning and daily use

Open `https://<TM_HOST>/` from another device and verify valid TLS, sign-in and
`/api/v1/health` returning `{"status":"ok"}`. Unauthenticated collection access
must return 401. With disposable records, confirm two-client automatic updates,
stale-edit rejection, reconnection, role checks, picture/QR workflows and persistence
after restart. A successful container health check alone is insufficient.
Use separate browser profiles for test stacks on the same host.

Healthy clients receive SSE hints and refresh affected data without page reload.
If streaming fails, conditional polling takes over. Drafts stay open; disconnected
writes are not queued and an uncertain response must be checked against server
state before retrying. Do not add SSE buffering/compression overrides to Caddy;
see [change contract](shared-care-change-contract.md).

Administrators manage accounts under Settings → Server → Manage accounts and
review metadata under Settings → Shared server → Audit. Account changes revoke
sessions; the final active administrator is protected. Audit retention is 365
days. Storage/audit failure rolls back a mutation: repair storage rather than
disabling audit. Roles, upload limits and retry receipts are in the [API](shared-care-api.md).

## Backups and restore

| Backup | Contains | Use |
| --- | --- | --- |
| Portable `.tmbackup` | Collection, histories and pictures; no accounts/sessions/audit/personal preferences | Transfer or replace the shared collection |
| Stopped `data/` snapshot | Both SQLite files and security-sensitive account/session/audit data | Full server disaster recovery |

`deploy/data` is a local bind mount containing `collection.sqlite`, `accounts.sqlite`
and active WAL files. Do not use a network share or run two servers against it.
For a consistent full snapshot, from `deploy/`:

```sh
docker compose stop server
sudo tar --acls --xattrs --numeric-owner \
  -czf backups/terramanager-$(date +%Y%m%d-%H%M%S).tar.gz data
docker compose start server
docker compose ps
```

Keep protected copies on separate storage and test recovery in an isolated
installation. A live directory copy can miss WAL writes. Host snapshots are
not encrypted by TerraManager and include account hashes/active sessions.

For portable replacement, administrators save a current safety copy, select and
preview the archive, then confirm. Only a server-confirmed empty collection can
skip the safety export. Concurrent writes invalidate the grant. Failed validation/
replacement preserves existing data; successful restore resets connected views
automatically. Accounts remain intact. The server accepts at most 256 MiB compressed /
512 MiB expanded; larger transfers need a planned migration, not bypassed limits.

Protected portable export/import happens in the browser; the server processes
the inner ZIP over HTTPS. Private temporary server spools are encrypted and
removed after the operation. Large client operations still have proportional
memory costs and can take minutes. After a lost completion response, wait for
availability and inspect counts/pictures before retrying. Diagnose client/network
upload problems separately from backup-format failures.

## Update, rollback and maintenance

Keep old image tags and a stopped pre-update volume snapshot. Select the new
source revision, transfer matching Web output and set its image tag:

```sh
docker compose config
docker compose build
docker compose up -d --no-build
docker compose ps
```

Check trusted HTTPS, health, login, automatic updates and representative data.
To roll back, stop the stack and restore both the old code/images and matching
pre-update data snapshot; old code may not read a new schema. Retain failed-upgrade
data separately. Certificate renewal replaces the matching chain/key and restarts
`web`; keep hostname and client trust aligned.

For legacy orphaned media, take a backup, stop `server`, then run the dry-run
`docker compose run --rm --no-deps --entrypoint /opt/media/bin/cleanup_media server`.
Review counts before adding `--apply`; the transaction rechecks gallery/primary
references. Start the server again afterward. Never remove referenced pictures.

CI verifies server locks, ARM64 build and isolated bootstrap/health. Target TLS,
device behavior and disaster recovery remain installation-specific checks.
