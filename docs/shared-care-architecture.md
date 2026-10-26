---
layout: default
title: Shared Care code organization
permalink: /shared-care-architecture.html
---

# Shared Care code organization

Shared Care separates browser presentation from server-owned persistence and
reuses standalone domain/repository code. The collection is schema 18; portable
format 2 and API routes are documented in their respective contracts.

## Client

`lib/main_shared.dart` composes `shared_client/app/shared_care_app.dart`.
Feature folders contain `presentation/pages`, reusable `presentation/widgets`
and `infrastructure/api` mixins: Animals, Boxes/QR, Feedings, care history, media,
backups, settings, authentication and administration/accounts/audit.
`navigation` owns detail context and browser Back; `shared` owns transport,
synchronization and common labels/widgets.

`SharedApiClient` composes feature APIs over one transport/session. The
synchronization controller invalidates affected data and coordinates SSE,
conditional fallback and recovery. See the [change contract](shared-care-change-contract.md).
No client imports server persistence or opens a collection database. Reusing
pure enums, formatting and picture-selection widgets is allowed.

Browser-history writes are serialized; acknowledging an in-app pop must not
dispatch a second Back. Archive routes receive refreshed snapshots and retain
their own sort order. Reconciliation preserves mounted edit drafts. Care-event
dialogs edit local dates/times and encode UTC instants for the API.

## Server

`bin/shared_server.dart` composes `shared_server/app/shared_server_api.dart`.
Global routing enforces origin/session/role guards, health and error translation;
`collection/infrastructure/http/care_api.dart` dispatches collection resources.

| Layer | Responsibility |
| --- | --- |
| `<feature>/infrastructure/http/` | Routes, bounded request decoding, HTTP responses |
| `<feature>/application/` | Typed validation, commands, conflicts, lifecycle and transaction orchestration |
| `<feature>/domain/` | Results/errors, identity and allowlisted audit metadata |
| `<feature>/infrastructure/` | SQLite accounts, password hashing and audit storage |
| `shared/infrastructure/` | Database connection, HTTP readers/writers and serialization |

Operations reuse `core/database/repositories/`. Weight/shedding belong to Animals;
authentication, administration, backups and change delivery have dedicated
modules. Publish revision hints only after collection/audit commit. Preserve
backup safety gates and idempotency receipts.

## Dependency rules

- Browser code: no server, Drift or SQLite persistence imports.
- Server application operations: no Flutter UI or HTTP implementation imports.
- Import canonical feature paths; old flat files are export-only adapters.
- Organization changes must preserve API, transaction and authorization contracts.

`test/architecture/` checks these boundaries and compatibility exports.
See [ADR-035](architecture-decisions.md#adr-035-organize-shared-care-by-feature-with-explicit-transport-and-persistence-boundaries).
