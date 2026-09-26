# Shared Care API

This document describes the server-owned care API from Issue #157 and local
caregiver authentication from Issue #158. The ARM64 container layout and LAN
HTTPS deployment are described in [Shared Care deployment](shared-care-deployment.md).
The API-backed Flutter Web client is `lib/main_shared.dart` (Issue #160).

## Data ownership

The server opens one collection SQLite database file on persistent local
storage. It runs the existing Drift migrations before accepting requests. A
separate SQLite file holds local accounts and sessions. The server alone holds
both database connections; API clients cannot request either file or execute
SQL. Existing standalone Android and Web modes keep their local database
behavior. Shared-mode browsers use this API only; their presentation
preferences remain local.

Media assets remain in the SQLite `MediaAssets` table. Local accounts and
sessions live in a separate `accounts.sqlite` database beside the collection
database by default. Keep both files and their WAL files in persistent storage,
not in a disposable container layer. Do not place live SQLite files on a
network share. The portable collection backup does not include accounts.

## Starting the API

Set `TM_DATABASE_PATH` to the absolute collection database path. From an
interactive terminal, run `dart run bin/create_admin.dart` once. It prompts for
an administrator username and a password of at least 12 characters without
echoing the password or accepting it on the command line. Startup refuses to
serve a collection until this administrator exists; there is no default login.

Then run `dart run bin/shared_server.dart` with:

| Variable | Required | Meaning |
| --- | --- | --- |
| `TM_DATABASE_PATH` | yes | Absolute path of the server-owned SQLite file |
| `TM_PUBLIC_ORIGIN` | yes | Exact browser origin, for example `https://terramanager.example` |
| `TM_AUTH_DATABASE_PATH` | no | Account database; defaults to `accounts.sqlite` beside the collection file |
| `TM_BIND_ADDRESS` | no | Listener address; defaults to `127.0.0.1` |
| `TM_PORT` | no | Listener port; defaults to `8080` |

The default loopback binding keeps the API private until an HTTPS reverse
proxy is configured. Non-local `TM_PUBLIC_ORIGIN` values must use HTTPS. The
server does not contact any external identity, analytics or tracking service.
Account credentials and session cookies must never traverse an unencrypted LAN
connection. Server file permissions should limit access to both databases.

All API paths use the `/api/v1` prefix. `GET /api/v1/health` is an unauthenticated
readiness check that tests the database connection and returns only `status`.
Collection and media paths require an
active local account session. Login sets a host-only `Secure`, `HttpOnly`,
`SameSite=Strict` cookie. Session tokens are random, stored only as SHA-256
digests on the server, expire after 12 hours and are revoked on logout or
account changes. The login response and `GET /auth/session` provide a
session-specific CSRF token; send it in `X-CSRF-Token` on every POST, PUT, PATCH
and DELETE. Cross-origin writes are rejected. No CORS access is granted.

Requests and responses containing records use JSON. The Animal list includes
`latestFeedingAt` as a nullable UTC timestamp calculated for the whole list in
one database query. This read-only overview field is not part of the Animal
revision token and updates after a Feeding is added, edited or deleted.
Dates in write requests
must use ISO-8601 with `Z` or a numeric time-zone offset. Server responses use
UTC ISO-8601 timestamps. A client should clear its local login state on
`401 unauthorized`, show the denied operation on `403 forbidden` or `403 csrf_failed`,
and redirect to login after expiry. The browser client refreshes visible
overviews and details every 15 seconds, refreshes immediately after a save or
when the browser returns to the foreground, and offers a manual reload after
connection failures. Hidden browser tabs do not poll. It does not queue edits while
disconnected.

Overview media reads reuse the authenticated client. The browser retains a
bounded, in-memory picture snapshot for the current overview. Routine polling
updates records without downloading unchanged pictures; manual reload, detail
return and a new overview visit renew the snapshot. Changing a primary media ID
loads the new image. The cache does not modify server media ownership, media
routes, authorization or the `no-store` response policy.

## Local accounts

| Route | Access | Purpose |
| --- | --- | --- |
| `POST /auth/login` | public | Log in with local username and password; returns user, CSRF token and expiry |
| `GET /auth/session` | signed in | Recover current user, CSRF token and expiry after a reload |
| `POST /auth/logout` | signed in, CSRF | Revoke the current session |
| `GET /admin/accounts` | administrator | List local accounts without password hashes |
| `POST /admin/accounts` | administrator, CSRF | Add an administrator or caregiver |
| `PATCH /admin/accounts/{id}` | administrator, CSRF | Change username/role, reset password or activate/deactivate; revokes that user's sessions |
| `DELETE /admin/accounts/{id}` | administrator, CSRF | Confirmed removal of credentials and sessions; preserves audit attribution |

Usernames use 3–64 lower-case ASCII letters, digits, dots, underscores or
dashes and begin with a letter or digit. Names are trimmed and case-normalized
before uniqueness checks. Passwords are individually salted and hashed with Argon2id (19 MiB,
two iterations, one lane). No plaintext password is written to either SQLite
file. The final active administrator cannot be demoted, deactivated or removed.
Caregivers may read and edit collection and care records, including media, but
cannot manage accounts or portable backups. Administrator backup export and
full restore include collection records and picture galleries, but not accounts
or sessions.

The administrator interface is Settings → Server → Manage accounts. PATCH
accepts a nonempty subset of `username`, `role`, `password` and `active`.
An omitted password retains the existing hash; an empty or too-short password
is rejected. DELETE requires the JSON body `{"confirmation":"remove-account"}`
and an `expectedAuditId` matching the account selected for removal, as well as
a valid administrator session, same-origin request and CSRF token. Administrator
account responses expose this non-secret stable identity. The browser also
sends it with PATCH, and the store checks it again inside the transaction so an
old form cannot target a replacement account that reused the same row number.
Edit and delete responses include `sessionRevoked` to tell the caller whether
its own session was revoked. Self-edit/removal returns the client to sign-in.

Account changes and their audit rows commit in the same transaction. The store
rechecks the acting administrator and last-active-administrator constraint at
commit time, including after asynchronous password hashing. Removing an account
cascades to its sessions, deletes its credential hash and preserves earlier
metadata in `shared_audit_events`; a new account with a reused name or row ID
receives a new audit identity. Portable collection restore is unaffected.

## Operations

| Resource | Routes |
| --- | --- |
| Boxes | `GET/POST /boxes`, `GET/PATCH/DELETE /boxes/{id}`, `POST /boxes/{id}/duplicate`, `POST /boxes/{id}/archive`, `POST /boxes/{id}/restore`, `GET /boxes/qr/{qrId}` |
| Animals | `GET/POST /animals`, `GET/PUT/DELETE /animals/{id}`, `PUT /animals/{id}/feeding-reminder`, `POST /animals/{id}/duplicate`, `POST /animals/{id}/move`, `POST /animals/{id}/archive`, `POST /animals/{id}/restore` |
| Feeding | `POST /feedings` with a nonempty `animalIds` list and optional `boxId` for Box-scoped Feeding Mode, `GET/PUT/DELETE /feedings/{id}`, `GET /animals/{id}/feedings` |
| Feeding reminders | `GET /reminders` returns configured active Animals with `animalId`, `dueAt` and optional `latestFeedingAt` |
| Weight | `GET/POST /animals/{id}/weights`, `PUT/DELETE /animals/{id}/weights/{entryId}` |
| Shedding | `GET/POST /animals/{id}/shedding`, `PUT/DELETE /animals/{id}/shedding/{eventId}` |
| Picture galleries | `GET/POST /boxes/{id}/pictures` and `/animals/{id}/pictures`; `DELETE /.../pictures/{mediaId}`; `POST /.../pictures/{mediaId}/primary` |
| Media | `POST /media` with `fileName`, `mimeType` and `dataBase64`; `GET /media/{id}` returns image bytes |
| Portable backup | Administrator-only `GET /admin/backups` downloads a `.tmbackup`; `POST /admin/backups/restore` replaces the collection after confirmation |

Creation of a Box generates its permanent QR identifier on the server.
The Shared Care browser scanner decodes a printed Box code locally and sends
only its validated identifier to `GET /boxes/qr/{qrId}` over the same HTTPS
origin. The server returns the current Box or `404`; the client refuses to
open archived Boxes from the scanner. Camera frames are not an API payload.
Animal creation and replacement require `boxId`, `commonName`,
`latinName`, `tempMin`, `tempMax`, `humidityMin`, and `humidityMax`.
Animal `PUT` is a full replacement of editable fields and also requires
`category`, `showWeightOnDetail`, and `showSheddingOnDetail`. Box
`PATCH` changes only supplied fields. Clients cannot assign record IDs,
status, QR identifiers or archive timestamps through ordinary edit requests.

Every Box and Animal response includes an opaque `revision`. A Box `PATCH` or
Animal `PUT` must include the `expectedRevision` from the record the editor
opened. The server compares it inside the write transaction. If another
caregiver changed the record, it returns `409 stale_record` and writes nothing;
the client must reload and review the latest record before another attempt.
Revisions cover record data rather than relying on the timestamp precision of
SQLite. New records do not need an expected revision.

`POST /animals/{id}/move` accepts the destination `boxId` and an optional
`expectedRevision`. Shared Care's QR Rehouse flow always sends the revision
from the opened Animal. The server compares it in the same transaction as the
move, then rechecks that the Animal and destination Box are active and that the
destination differs from the current Box. A stale revision returns
`409 stale_record`; no assignment changes.

`PUT /animals/{id}/feeding-reminder` updates only the reminder configuration.
It requires `expectedRevision`; `intervalDays` and `baseline` must either
both be set or both be `null`. The interval must be a positive integer and the
baseline an ISO-8601 timestamp with an offset. The server rejects archived
Animals and stale revisions. `GET /reminders` uses the same database-backed
reminder calculation as the standalone app: the latest Feeding supersedes the
baseline, and the next due time is that timestamp plus the interval. The
response contains no browser-specific preferences or notification state.

`POST /feedings` requires a UUID `Idempotency-Key` header. Repeating the same
request with the same key during the server process lifetime returns its first
result without adding more events; reusing a key with different data returns
`409 idempotency_conflict`. The server retains successful keys for 24 hours.
The browser generates one key for each new feeding submission and reuses it
when retrying the unchanged request. If `boxId` is supplied, the server also
requires that Box to be active and every selected Animal to be active and still
assigned to it inside the write transaction. A changed assignment rejects the
entire group. If a connection fails after submitting, check the server history
before creating a new entry.

The API applies the existing environmental, taxonomy, Box-assignment and
lifecycle rules on the server. Grouped feeding and Animal reassignment run
inside database transactions. Only archived Boxes and Animals can be
permanently deleted. Direct gallery uploads add the image and association in
one transaction. Image uploads accept PNG, JPEG and WebP up to 8 MiB; they are
authenticated like every collection endpoint.

## Errors

Errors have the stable shape
`{"error":{"code":"invalid_data","message":"..."}}`.

| HTTP status | Code | Meaning |
| --- | --- | --- |
| 400 | `invalid_json`, `invalid_data` | Malformed or rejected input |
| 401 | `unauthorized`, `invalid_credentials` | Missing/expired session or invalid login |
| 403 | `forbidden`, `csrf_failed` | Role, origin or CSRF token denied the request |
| 404 | `not_found` | Unknown route or record |
| 409 | `conflict` | Lifecycle or relationship rule prevents the change |
| 409 | `stale_record` | Record changed since the editor opened; reload and review it |
| 409 | `idempotency_conflict` | A feeding request key was reused with different data |
| 413 | `too_large` | Request exceeds the body limit |
| 415 | `unsupported_media_type` | Write request is not JSON |
| 429 | `rate_limited` | Too many failed login attempts in five minutes |
| 500 | `internal_error` | Unexpected server failure; details are not returned |

## Portable backup and restore

`GET /admin/backups` returns the standard Backup Format 2 archive with
`application/vnd.terramanager.backup+zip`. The browser saves it to an
administrator-chosen location. Its `settings.json` has `scope: collectionOnly`
and neutral required settings values; no caregiver's browser preferences are
included. Restoring this archive in a standalone installation leaves that
installation's personal preferences intact. Existing compatible `.tmbackup`
archives can initialize an empty shared collection or replace a populated one.

The response also issues a short-lived, session-bound safety token. The admin
interface requires this current collection archive to be saved when collection
data exists. `GET /admin/backups/restore-status` is administrator-only and
returns `{"safetyBackupRequired": true|false}` with `Cache-Control: no-store`.
The browser checks it before selecting an archive; this response is advisory,
not authorization to overwrite later changes. An empty collection can be
initialized without `X-Safety-Token`. Emptiness means no rows in any collection
table, including archived records, care histories, picture associations and
unassociated media. Accounts and SQLite bookkeeping do not prevent first import.
The server checks emptiness again after acquiring the exclusive restore gate,
which drains existing mutations and prevents new writes through replacement.
If a caregiver added data during selection or upload, a missing safety token
returns `409 safety_backup_required` and preserves the collection. Populated
collections still require a valid, unexpired, session-bound safety token with
an unchanged generation. There is no opt-out for populated collections. The restore request sends the selected archive as the binary request
body, the normal CSRF token, the safety token, and
`X-Restore-Confirmation: replace-shared-collection`. The server validates the
archive again and refuses the restore if the shared collection changed after
the safety download. Export and restore temporarily block new collection
edits; restore uses one database transaction, so a failed replacement leaves
the previous collection intact. The token expires after 30 minutes and is
cleared after a successful restore. Restore requests above 256 MiB compressed
or 512 MiB expanded are refused before media extraction; larger collections
require a separate migration procedure.

The server keeps no uploaded archive or unencrypted temporary backup file.
Protect downloaded `.tmbackup` files: they contain records, notes and pictures
without encryption. The separate account database is not exported or replaced,
so caregiver logins remain in place. The shared Flutter Web client uses this API
for Box, Animal, archive, care, picture, backup and account workflows; its
deployment is described in
[Shared Care deployment](shared-care-deployment.md).


## Server audit metadata

Issue #177 records authenticated collection mutations (Boxes, Animals, Feeding,
weight and shedding history, media, archive/restore and reassignment), portable
restore, and account administration. Each event stores UTC time, a stable actor
identifier, actor name/role snapshots, a fixed action, affected record type/ID,
outcome and HTTP status. Grouped Feedings identify each affected Feeding record;
an idempotent retry is marked `replayed`, not a second Feeding creation.

Collection audit rows commit in the same transaction as the collection change;
account audit rows commit in the same transaction as the account change. If an
audit write fails, the mutation is rolled back and receives an error response.
This includes backup replacement and prevents cached Feeding successes from
surviving rollback. A lost HTTP response still requires checking the current
collection before retrying an operation without idempotency protection.

The server stores collection events in `collection.sqlite` and account events
in `accounts.sqlite`. Both use `shared_audit_events`; neither stream is a
portable collection table. Portable export excludes them and portable restore
preserves them. Account target identifiers are stable audit identifiers rather
than reusable account row numbers. Collection record IDs refer to their
collection state at the event time; `collection.restore` marks replacement.
Audit fields never contain request bodies, notes, picture/file bytes, filenames,
password hashes, passwords, CSRF values, session tokens or idempotency keys.

Audit metadata is pruned after 365 days at startup and on new audit writes.
Account deactivation/removal does not cascade into these rows. Unauthorized and
CSRF-denied requests are not collection-change audit entries. The administrator
viewer and its read-only endpoints are separate work in Issue #179; this change
does not expose a new public audit API.
