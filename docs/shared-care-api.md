# Shared Care API

This document describes the server foundation for Issue #157. The API is not
the shared Web client or the final account system. Issue #158 replaces its
temporary bearer credential with local caregiver accounts and browser sessions.
Never embed the temporary credential in a Web build.

## Data ownership

The server opens one SQLite database file on persistent local storage. It runs
the existing Drift migrations before accepting requests. The server alone
holds the database connection; API clients cannot request the SQLite file or
execute SQL. Existing standalone Android and Web modes keep their local
database behavior.

Media assets remain in the SQLite `MediaAssets` table. Keep the database file
and its WAL files in persistent storage, not in a disposable container layer.
Do not place the live SQLite file on a network share.

## Starting the API

Run `dart run bin/shared_server.dart` with:

| Variable | Required | Meaning |
| --- | --- | --- |
| `TM_DATABASE_PATH` | yes | Absolute path of the server-owned SQLite file |
| `TM_API_TOKEN` | yes | Random secret of at least 32 characters; temporary until Issue #158 |
| `TM_BIND_ADDRESS` | no | Listener address; defaults to `127.0.0.1` |
| `TM_PORT` | no | Listener port; defaults to `8080` |

The default loopback binding avoids exposing the temporary credential on the
LAN. A deployment serving other devices must place the API behind HTTPS and
must not expose an unencrypted token-bearing listener. The server does not
contact any external service.

All API paths use the `/api/v1` prefix and require
`Authorization: Bearer <token>`. Requests and responses containing records
use JSON. Dates in write requests must use ISO-8601 with `Z` or a numeric
time-zone offset. Server responses use UTC ISO-8601 timestamps. There are no
cross-origin access headers; the later shared Web application should use the
same origin.

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
| 401 | `unauthorized` | Missing or invalid temporary credential |
| 404 | `not_found` | Unknown route or record |
| 409 | `conflict` | Lifecycle or relationship rule prevents the change |
| 413 | `too_large` | Request exceeds the body limit |
| 415 | `unsupported_media_type` | Write request is not JSON |
| 500 | `internal_error` | Unexpected server failure; details are not returned |

The temporary credential has no per-person identity or roles. Account
creation, secure browser sessions, access roles and logout belong to Issue
#158. Backup import and the complete shared Web workflow are later work.
