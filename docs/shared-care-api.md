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

Requests and responses containing records use JSON. Dates in write requests
must use ISO-8601 with `Z` or a numeric time-zone offset. Server responses use
UTC ISO-8601 timestamps. A client should clear its local login state on
`401 unauthorized`, show the denied operation on `403 forbidden` or `403 csrf_failed`,
and redirect to login after expiry. The browser client polls the collection
periodically and offers a manual reload after connection failures. It does not
queue edits while disconnected.

## Local accounts

| Route | Access | Purpose |
| --- | --- | --- |
| `POST /auth/login` | public | Log in with local username and password; returns user, CSRF token and expiry |
| `GET /auth/session` | signed in | Recover current user, CSRF token and expiry after a reload |
| `POST /auth/logout` | signed in, CSRF | Revoke the current session |
| `GET /admin/accounts` | administrator | List local accounts without password hashes |
| `POST /admin/accounts` | administrator, CSRF | Add an administrator or caregiver |
| `PATCH /admin/accounts/{id}` | administrator, CSRF | Change role, reset password or activate/deactivate; revokes that user's sessions |

Usernames use 3–64 lower-case ASCII letters, digits, dots, underscores or
dashes. Passwords are individually salted and hashed with Argon2id (19 MiB,
two iterations, one lane). No plaintext password is written to either SQLite
file. The final active administrator cannot be demoted or deactivated.
Caregivers may read and edit collection and care records, including media, but
cannot manage accounts. Full collection backup restore is not implemented in
this API yet; its future route must be administrator-only.

## Operations

| Resource | Routes |
| --- | --- |
| Boxes | `GET/POST /boxes`, `GET/PATCH/DELETE /boxes/{id}`, `POST /boxes/{id}/duplicate`, `POST /boxes/{id}/archive`, `POST /boxes/{id}/restore`, `GET /boxes/qr/{qrId}` |
| Animals | `GET/POST /animals`, `GET/PUT/DELETE /animals/{id}`, `POST /animals/{id}/duplicate`, `POST /animals/{id}/move`, `POST /animals/{id}/archive`, `POST /animals/{id}/restore` |
| Feeding | `POST /feedings` with a nonempty `animalIds` list, `GET/PUT/DELETE /feedings/{id}`, `GET /animals/{id}/feedings` |
| Weight | `GET/POST /animals/{id}/weights`, `PUT/DELETE /animals/{id}/weights/{entryId}` |
| Shedding | `GET/POST /animals/{id}/shedding`, `PUT/DELETE /animals/{id}/shedding/{eventId}` |
| Picture galleries | `GET/POST /boxes/{id}/pictures` and `/animals/{id}/pictures`; `DELETE /.../pictures/{mediaId}`; `POST /.../pictures/{mediaId}/primary` |
| Media | `POST /media` with `fileName`, `mimeType` and `dataBase64`; `GET /media/{id}` returns image bytes |

Creation of a Box generates its permanent QR identifier on the server.
Animal creation and replacement require `boxId`, `commonName`,
`latinName`, `tempMin`, `tempMax`, `humidityMin`, and `humidityMax`.
Animal `PUT` is a full replacement of editable fields and also requires
`category`, `showWeightOnDetail`, and `showSheddingOnDetail`. Box
`PATCH` changes only supplied fields. Clients cannot assign record IDs,
status, QR identifiers or archive timestamps through ordinary edit requests.

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
| 413 | `too_large` | Request exceeds the body limit |
| 415 | `unsupported_media_type` | Write request is not JSON |
| 429 | `rate_limited` | Too many failed login attempts in five minutes |
| 500 | `internal_error` | Unexpected server failure; details are not returned |

Portable backup import for the server-owned collection remains future work.
The shared Flutter Web client uses this API for Box, Animal, archive, care,
picture and account workflows; its deployment is described in
[Shared Care deployment](shared-care-deployment.md).
