# Shared Care API

The server owns one collection SQLite file and a separate account/session file.
Browsers use the API and transient view state; standalone collections remain
independent. Use the [deployment guide](shared-care-deployment.md) for containers.

## Run locally

Run `dart run bin/create_admin.dart` interactively before starting
`dart run bin/shared_server.dart`. There is no default login. Administrator
passwords require at least 12 characters; do not pass them as command arguments.

| Environment | Requirement / default |
| --- | --- |
| `TM_DATABASE_PATH` | Required absolute collection path |
| `TM_PUBLIC_ORIGIN` | Required exact browser origin; HTTPS outside loopback |
| `TM_AUTH_DATABASE_PATH` | Defaults to `accounts.sqlite` beside collection |
| `TM_BIND_ADDRESS` | `127.0.0.1` |
| `TM_PORT` | `8080` |

Keep live databases on local persistent storage with restricted access.

## Authentication and authorization

All routes below use `/api/v1`. Health is public; collection/media reads require
an active account. The host-only session cookie is `Secure`, `HttpOnly` and
`SameSite=Strict`; its server-side digest expires after 12 hours, independent of
recent activity. Logout and account changes revoke affected sessions.
Send `X-CSRF-Token` on POST/PUT/PATCH/DELETE. Cross-origin writes are rejected;
the API grants no CORS access.

Caregivers can read, create, edit, duplicate, archive, restore records and select
primary pictures. All collection DELETE routes, account administration, audit
viewing and portable server backups require administrator role.

| Route | Purpose |
| --- | --- |
| `GET /health` | Database readiness; status only |
| `POST /auth/login` | Username/password; returns user, CSRF, expiry/preferences |
| `GET /auth/session` | Current session snapshot |
| `POST /auth/logout` | Revoke current session |
| `GET/PATCH /auth/preferences` | Own allowlisted account preferences only |
| `GET/POST /admin/accounts` | List/create accounts |
| `PATCH/DELETE /admin/accounts/{id}` | Edit or confirmed account removal |

Usernames are normalized 3-64-character lower-case ASCII identifiers beginning
with a letter/digit, followed by letters, digits, `.`, `_` or `-`. Passwords use
salted Argon2id (19 MiB, two iterations, one lane). Account PATCH accepts a
nonempty subset of `username`, `role`, `password`, `active`; omitted password
keeps the hash. Send the stable `expectedAuditId` to protect against reused row
IDs; DELETE also requires `{"confirmation":"remove-account"}`. A response's
`sessionRevoked` handles self-edits/removal. Transactions protect the final
active administrator and retain historical attribution after account deletion.

The personal `feeding_alert_suppressions` preference maps `animalId:createdAtMillis`
to UTC Unix expiry milliseconds. PATCH merges individual Animals, prunes expired
entries and accepts at most 1,000 active entries. It hides only overview alerts
for that account; schedules, history and detail banners are unchanged.

Preferences include appearance, language, naming, sorting, category grouping,
Big Picture, Next Feeding and archive orders. `show_empty_boxes_last` is a personal
boolean (default false) for placing empty Boxes last. Unknown fields/values return 400.
They belong to the account and are excluded from portable collection backups.

## Collection routes

| Resource | Routes |
| --- | --- |
| Boxes | `GET/POST /boxes`; `GET/PATCH/DELETE /boxes/{id}`; `POST /boxes/{id}/duplicate`, `/archive`, `/restore`; `GET /boxes/qr/{qrId}` |
| Animals | `GET/POST /animals`; `GET/PUT/DELETE /animals/{id}`; `POST /animals/{id}/duplicate`, `/move`, `/archive`, `/restore`; `PUT /animals/{id}/feeding-reminder` |
| Feedings | `POST /feedings`; `GET/PUT/DELETE /feedings/{id}`; `GET /animals/{id}/feedings` |
| Reminders | `GET /reminders` |
| Weight | `GET/POST /animals/{id}/weights`; `PUT/DELETE /animals/{id}/weights/{entryId}` |
| Shedding | `GET/POST /animals/{id}/shedding`; `PUT/DELETE /animals/{id}/shedding/{eventId}` |
| Box care | `GET/POST /boxes/{id}/care-events`; `PUT/DELETE /boxes/{id}/care-events/{eventId}` |
| Galleries | `GET/POST /animals/{id}/pictures` and `/boxes/{id}/pictures`; `DELETE /.../pictures/{mediaId}`; `POST /.../pictures/{mediaId}/primary` |
| Media | `GET /media/{id}`; standalone `POST /media` is unsupported |
| Changes | `GET /changes`, `GET /changes/events`; [contract](shared-care-change-contract.md) |
| Backups | `GET /admin/backups`, `POST /admin/backups/restore` |
| Audit | `GET /admin/audit` |

Requests/responses use JSON except media, backup and SSE bodies. Box creation
generates `qrId` on the server. Animal creation requires `boxId`, `commonName`,
`latinName`, `tempMin`, `tempMax`, `humidityMin`, `humidityMax`. Animal PUT replaces
editable fields and additionally requires `category`, `showWeightOnDetail`,
`showSheddingOnDetail`; Box PATCH changes supplied fields only. Ordinary edits
cannot assign IDs, QR values, lifecycle state or archive timestamps.

Box care POST requires `type` (`substrateChange`, `cleaning`, `waterChange`), UTC
`occurredAt` and a stable `requestId` (1–64 characters). `notes` is optional;
care events have no media fields.
PUT supplies `type`, `occurredAt`, optional `notes`, integer `expectedRevision` and immutable
`expectedRequestId`; DELETE supplies both guards. The identity guard also prevents
old drafts from changing a different event after restore reuses numeric IDs. Stale writes return `409 stale_record`. Retries of the same
POST return the existing entry without a second commit. Archived histories are
read-only; permanent deletion remains administrator-only. Committed care changes
invalidate `boxCareHistories` for the owning Box ID through the existing change stream.

## Conflicts, histories and retries

- Box/Animal responses include opaque `revision`. Editing requires the opened
  `expectedRevision`; comparison is transactional. `409 stale_record` requires
  reload/review. Move accepts the destination `boxId`; the browser also sends
  the revision. Recheck active state, destination and changed assignments.
- Instants require ISO-8601 with an offset; responses use UTC. Birth dates use
  `YYYY-MM-DD`. Animal lists expose derived `latestFeedingAt` separately from
  editable revision data.
- Feeding creation accepts nonempty `animalIds`, timestamp and optional notes/
  `boxId`. A supplied Box must still own all selected active Animals; otherwise
  the whole grouped write rolls back.
- Feedings require UUID `Idempotency-Key`; process-local successes last 24 hours.
  Repeating identical data returns the original result; changed data returns
  `409 idempotency_conflict`.
- Reminder PUT requires `expectedRevision`, paired interval/baseline or the
  weekly `weekdays`, `minuteOfDay`, `timeZone` configuration. Validate the same
  rules as [the data model](data-model.md).
- Galleries accept static PNG/JPEG/WebP: 8 MiB per image, 8,192 pixels per side,
  20,971,520 pixels total. Decode before storage; collection image bytes are
  limited to 512 MiB. Original bytes/orientation metadata are retained.
- Gallery UUID idempotency receipts commit with the picture, persist 30 days and
  survive restarts. Portable restore clears them. Old clients without a key
  cannot safely repeat an uncertain upload.

A lost response does not prove rollback. Reconcile server state before retrying
an operation without idempotency protection. The browser queues no offline writes.
SSE triggers targeted HTTP reads; it does not reload the page or replace drafts.

## Backup and audit

The [backup contract](backup-format.md) defines portable fields, formats and time
zone compatibility. Server export returns a plain format-2 ZIP and a session-bound
`X-Safety-Token` valid for 30 minutes at the unchanged collection generation.
Restore sends the binary ZIP, CSRF, this token and
`X-Restore-Confirmation: replace-shared-collection`. Legacy offset-free timestamps
also require `X-Backup-Time-Zone`. Only a genuinely empty collection can omit the
safety token; emptiness is rechecked under the exclusive restore gate.

Limits are 256 MiB compressed / 512 MiB expanded. Validation precedes atomic
replacement. Temporary server spools are encrypted per operation and removed
afterward; the API still transfers plaintext ZIP over HTTPS. Optional portable
password protection is performed in the browser. Accounts, sessions, preferences
and audit are neither exported nor replaced; stopped-volume backup protects them.

Collection/account audit rows commit with their mutations. Audit failure rolls
back the change. Metadata contains actor identity/name/role, UTC time, action,
record identity, outcome and HTTP status; no bodies, notes, filenames, media,
passwords or tokens. Retention is 365 days; account removal and portable restore
preserve retained attribution.

`GET /admin/audit` merges both sources newest first and returns
`{"events":[...],"nextCursor":...}`. Parameters: `limit` (1-100, default 20), opaque
`cursor`, inclusive UTC `from`, exclusive UTC `until`, literal case-insensitive
`actor` (1-64 characters), `action` (`create`, `update`, `delete`, `archive`,
`restore`, `duplicate`, `move`, `feeding-reminder`, `set_primary`). Keep filters
with the cursor. Unknown/repeated parameters or malformed values return 400.

## Errors

Shape: `{"error":{"code":"invalid_data","message":"..."}}`.

| HTTP | Codes / handling |
| --- | --- |
| 400 | `invalid_json`, `invalid_data` |
| 401 | `unauthorized`, `invalid_credentials`; return to sign-in |
| 403 | `forbidden`, `csrf_failed` |
| 404 | `not_found` |
| 409 | `conflict`, `stale_record`, `idempotency_conflict`, `safety_backup_required` |
| 413 | `too_large`, `media_storage_limit` |
| 415 | `unsupported_media_type` |
| 429 | `rate_limited`; honor retry delay |
| 503 | `restore_in_progress`; retry reads after recovery |
| 500 | `internal_error`; implementation details withheld |
