# Shared Care deployment on Raspberry Pi

This is the Shared Care deployment layout for a 64-bit Raspberry Pi OS host.
The server and HTTPS gateway run as ARM64 containers. The server owns one
collection SQLite database and one account/session SQLite database. Media is
stored in the collection database, so both files must be kept together.

**Shared Web mode:** The gateway serves the Flutter application compiled from
`lib/main_shared.dart`. This entry point does not create `AppDatabase` or a
browser collection database. It signs in through the same-origin API, reloads
the server collection and keeps appearance preferences in each browser. The
normal `lib/main.dart` entry point remains the standalone, browser-local mode.
Opening a standalone Web build at another URL will not connect it to this
server.

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

On each client, import the public CA certificate as a trusted certificate
authority for websites. On Android, use the device's certificate-installation
settings; Brave uses the browser/device trust configuration. On Firefox
desktop, import the CA under certificate authorities and enable website
trust. Verify that the browser reports a valid certificate for the exact
`TM_HOST` address, issued by the installed CA, with no manual security
exception. A saved exception for an old server certificate is not a substitute
for trusting the CA; remove it before retesting. Never import or copy the CA
private key to a caregiver device. Browser menus vary by version, so use the
browser's current certificate instructions when locating these settings.

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

Build the shared Flutter Web files on your development machine with its Flutter
SDK, then copy only the compiled `build/web` contents to
`deploy/web-dist/` on the Pi. Do not copy `.env`, the CA private key, signing
keys or local database files with them. The following example builds on the
development machine and transfers one archive:

```sh
flutter pub get
flutter build web --target lib/main_shared.dart --no-web-resources-cdn
tar -C build/web -czf terramanager-shared-web.tar.gz .
scp terramanager-shared-web.tar.gz <pi-user>@<pi-host>:~/TerraManager/deploy/
```

On the Pi, unpack it beside the Compose file:

```sh
cd ~/TerraManager/deploy
mkdir -p web-dist
tar -xzf terramanager-shared-web.tar.gz -C web-dist
test -f web-dist/index.html
test -f web-dist/assets/fonts/fallback/Roboto-Regular.ttf
```

The `--no-web-resources-cdn` flag bundles the Roboto text font locally. Without
it the shared interface may render without text on a LAN without public font
access. The image build refuses to proceed without `web-dist/index.html` and
the bundled Roboto font. Generated
Web files are ignored by Git; rebuild and transfer them for each source update.
The Web output is static and contains no server credentials or collection
data. Its rendering files are served from the Pi, not a third-party CDN.

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
shared sign-in page without a browser certificate warning after the local CA
is trusted. `https://<TM_HOST>/api/v1/health` should return `{"status":"ok"}`;
it contains no collection or account data. An unauthenticated request to
`/api/v1/boxes` should return `401`. Login and all record access use the
HTTPS origin. Sign in on two browsers, create a Box in one and reload the
other; both should show the same server record. Archive and restore a test
record, then disconnect one browser from the LAN: it should show a connection
error and refuse edits until it can reload. To inspect API operations, see
[Shared Care API](shared-care-api.md). Test again with WAN access disabled
while keeping the LAN active to verify that the installation uses no cloud
service. The Android app's Shared care Settings link opens this URL in the
external browser; it does not connect the app's local database to the server
or synchronize the two collections. The same Settings section links to the
project website and language-matched user guide for an explanation of both
modes. These browser links require no additional Android app permission.

## Shared Web acceptance checks

Use disposable records on two signed-in browsers before relying on shared mode
for care work:

1. Create a Box on one device. Confirm that it appears on the other after the
   automatic refresh (normally within 15 seconds), without a browser reload.
2. Open a Box edit form, interrupt that device's LAN connection, and try to
   save once. The form must remain open and show that the outcome is uncertain;
   the application must not announce a successful save. After a failed request,
   further saves remain disabled until the server can be reached again.
3. Restore the connection and use **Reload**. Confirm that the current Box and
   Animal lists come from the server, including a change made in the other
   browser while the first was disconnected. Check the record before retrying
   a failed save: the server may have committed it before its reply was lost.
4. In the browser's developer tools, inspect storage for the shared HTTPS
   origin. There must be no TerraManager collection database in IndexedDB.
   Local browser storage may contain personal presentation preferences. The
   standalone Web application uses its own local collection at its separate
   origin and must not be mistaken for the shared client.
5. Open the same Box or Animal edit form in both browsers. Save a change in
   the first browser, then try to save the older form in the second. The second
   save must be rejected. Go back, review the refreshed record, and open a new
   edit form before applying the intended change.
6. Create one Feeding entry and check both browsers' histories. Repeated
   submission of the same request must not create a second event. Archive an
   Animal while another browser shows its detail page; the changed lifecycle
   state should appear on that page after its next visible refresh.

The shared browser overview follows the standalone Box and Animal navigation:
natural Box sorting, Animal created/name/age/latest-Feeding sorting, category
grouping, archive views, optional Big Picture cards, thumbnails, add buttons
and long-press/right-click action menus. Box and Animal rename, edit,
duplicate and archive actions use the care API. The Animal action menu can
open a new Feeding entry directly. Animal details show the primary picture,
gallery, latest Feeding and an active Feeding reminder, plus weight and
shedding summaries when enabled for that Animal. Box details show assigned
Animal thumbnails; archived details retain reason, date and notes. Presentation choices
remain per browser; collection records stay server-owned.

Shared Settings follows the standalone page's appearance and language
controls. Sorting, category grouping and Big Picture Mode are changed directly
on the relevant overview; these choices remain local to the browser. Server
status, administrator backups, caregiver accounts and sign-out are grouped in
the **Shared server** section, so it is clear which actions affect everyone.

The active Box overview offers **Scan Box**. On a supported mobile browser,
opening it asks for browser camera permission, recognizes the printed Box QR
code on the device and sends only its validated identifier to the same-origin
care API. It opens the active Box detail page. Unknown or archived Boxes are
rejected with an explanation. Camera frames are not uploaded. Shared mode
forces the browser's native `BarcodeDetector` reader; it does not load a
scanner library from a public CDN. A browser without that native reader,
including current Firefox, cannot use this scanner. Other collection actions
remain available there. Use a supported Chromium-based mobile browser for the
QR acceptance check.

The same overview also offers **Feeding Mode**. Scan a Box QR label, select the
active Animals in that Box, choose the Feeding date and optional notes, and
save the group in one server transaction. The scanner is ready for another Box
after saving. On a browser without native QR recognition, including Firefox,
use **Choose Box** in Feeding Mode instead of the camera. The server rejects
the whole group if the Box is archived or an Animal is no longer assigned to
that Box. A failed response may leave the save outcome uncertain: check the
Feeding history before starting a new submission.

**Edit Animal** also offers a QR button beside the Box selector. It scans a
different active Box and asks for confirmation before moving the Animal. If
the form has unsaved edits, the user must explicitly discard them before
scanning; the move changes only the Box assignment. A concurrent edit causes
the move to fail with a reload-and-review message. The ordinary Box selector
remains available when camera scanning is unsupported.

Feeding reminders can be enabled while creating or editing an Animal, or
changed independently from the reminder button on its detail page. Enabling
a reminder records the current time as its baseline; later Feedings become
the reference for the next due date. The active Animal overview shows due
Animals and the next upcoming Feeding, with links to their details. The
server calculates these dates from its shared records, so a Feeding entered
by another caregiver updates the view on the next foreground refresh. These
are in-app reminders only: Shared Care does not request browser notification
permission, schedule background work, or send push notifications.

The browser still has some intentional shared-mode differences. Bulk QR export
is not yet offered by this shared interface. Administrators can export and
restore portable collection backups in Shared Settings. Host-volume backups remain the
recovery path for both collection and account databases. Do not use the standalone Web application's
local database as a shared-care substitute.

### Complete field validation

Perform these checks with disposable records on the Pi before putting a new
deployment into routine use. Record the source revision, browser versions and
results in the operator's deployment log; automated tests cannot prove that a
particular phone, camera and certificate work together.

1. On two signed-in devices, create and edit a Box and Animal, record a grouped
   Feeding, edit a Feeding history entry, add an Animal weight/shedding entry
   and upload a Box and Animal picture. Confirm each change and image appears
   on the other device after its next visible refresh (normally within 15
   seconds). Check thumbnails and full-size picture retrieval.
2. On the mobile device, open `https://<TM_HOST>/` with the local CA trusted by
   that browser. Open **Scan Box**, grant camera access, scan a real printed
   label and confirm that the matching Box details open. An invalid or unknown
   code must not open another record. Check that the browser's network panel
   shows no request to a public decoder CDN. An ordinary
   `http://<LAN-IP>/` page is not an authenticated or camera-capable Shared
   Care setup.
3. Perform the connection-loss and simultaneous-edit checks above. Also
   verify that a signed-out or expired session cannot read Boxes, Animals or
   media, and that a caregiver cannot create accounts or restore backups.
4. As an administrator, download a portable `.tmbackup` with pictures and
   history. Validate and restore it **in a separate disposable installation**,
   then compare record counts, history and picture bytes. Never test restore
   by replacing the only live collection. Restart the disposable server and
   verify that its restored records still exist.
5. Stop the production server, take and verify a host-volume archive using the
   procedure below, then start it again. Confirm records and pictures still
   appear after the restart. For a full disaster-recovery test, restore the
   archive to an isolated host or directory and verify both collection and
   account login there. Do not run two server processes against one volume.
6. Disable WAN access while keeping the LAN active. Repeat login, Box lookup,
   QR scanning and picture retrieval. No external account, analytics,
   tracking, cloud or scanner CDN must be required for routine operation.

Field testing on one Pi installation has confirmed cross-device Box creation
and Feeding updates, Box QR scanning on a mobile browser over trusted HTTPS,
stale-edit rejection and portable backup restore in a separate disposable
stack. Both mobile and laptop browsers completed a restore in that test stack.
These observations apply to that installation; repeat the full checklist for
each new deployment and material update, including picture and history
comparison, access-control checks and stopped-volume disaster recovery.

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
sudo tar --acls --xattrs --numeric-owner \
  -czf backups/terramanager-$(date +%Y%m%d-%H%M%S).tar.gz data
docker compose start server
docker compose ps
```

Keep backup archives on separately protected storage. A backup of the live
database without stopping the server can omit writes still in SQLite's WAL.
Protect the archives like the original database: they contain pictures,
animal records, account hashes and active sessions. Verify a backup by
restoring it to an isolated test installation, not over the running server.

The administrator's **Save shared backup** action instead downloads a portable
`.tmbackup` containing all shared Boxes, Animals, histories and picture media.
It excludes `accounts.sqlite`, sessions and personal browser preferences. To
restore, save a fresh safety copy first, select a compatible backup, inspect
its record counts and confirm replacement. The server rejects an outdated
safety copy after another caregiver changes the collection. A failed import
does not replace existing data. Restore blocks collection edits until its
transaction ends; reload other open browsers afterwards. The browser and
server process these archives in memory and leave no temporary backup files
on the Pi. The 256 MiB compressed and 512 MiB expanded import limits protect
the Pi from oversized uploads.

On a Pi, restoring a larger archive can take several minutes. Keep the browser
page open. Other signed-in browsers may temporarily receive HTTP 503 while the
restore holds the collection. If the importing browser does not receive a
completion response, do not immediately retry: wait for the server to become
available, reload, and inspect the record counts and pictures first. A lost
response does not prove that the database transaction failed.

If only one client uploads slowly or times out, compare a disposable same-size
upload from that client with another device before changing server limits. In
field testing, a Windows laptop using a Hyper-V network bridge uploaded very
slowly with IPv4 Large Send Offload enabled on its virtual adapter; a phone on
the same LAN was fast. Disabling that offload setting restored laptop upload
speed and browser backup restore completed. Diagnose the affected client's
network configuration before repeating a restore; a timeout alone does not
identify a server or backup-format problem.

Keep downloaded archives in protected storage because portable backups are not
encrypted. For an installation with larger archives, use a separately planned
migration rather than bypassing the limit.

The portable export is a collection transfer, not a server disaster-recovery
backup: it omits caregiver accounts, password hashes and sessions. Conversely,
the stopped-server `data/` archive contains both SQLite databases and their
security-sensitive contents. Keep both types of backup under operator control.

## Update and rollback

Before updating, keep the old image tags available and make a stopped-server
volume backup. Then fetch the desired source revision, rebuild and transfer
the matching shared Web output, choose a new `TM_STACK_VERSION` in `.env`,
and run:

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
