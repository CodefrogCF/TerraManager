---
layout: default
title: Shared Care code organization
permalink: /shared-care-architecture.html
---

# Shared Care code organization

Shared Care follows the feature-oriented layout of the standalone app while
keeping its browser presentation separate from server-owned persistence.
Issue #185 changes source organization only. API paths and payloads, collection
schema version 16, portable backup format version 2, permissions and visible
workflows remain unchanged.

## Client

`lib/main_shared.dart` composes `shared_client/app/shared_care_app.dart`.
Feature pages live in `<feature>/presentation/pages/`, reusable feature widgets
in `<feature>/presentation/widgets/`, and feature API methods in
`<feature>/infrastructure/api/`.

| Feature | Responsibilities |
| --- | --- |
| `animals` | Overview, details, create/edit form, Weight and Shedding detail sections, Animal API commands |
| `boxes` | Overview, details, create/edit form, QR scanner and QR export, browser camera adapters, Box API commands |
| `feedings` | Box Feeding workflow, reminders, detail Feeding summary and Feeding API commands |
| `care_history` | Existing Feeding, Weight and Shedding history editor and history API commands |
| `media` | Gallery uploads and selection, thumbnails, overview image cache and Media API commands |
| `settings` | Settings page, account preference application and preferences API commands |
| `backups` | Backup Settings section, legacy-time-zone dialog, browser time-zone adapter and backup API commands |
| `administration/accounts` | Administrator account page and account API commands |
| `administration/audit` | Administrator audit page, metadata models and audit API commands |
| `authentication` | Sign-in page, session model and authentication API commands |
| `navigation` | Home navigation, detail navigation context and browser Back adapters |
| `shared` | Transient API transport, API error/payload validation, labels, sorting and reusable dialogs/widgets |

`SharedApiClient` composes the feature API mixins over a single
`SharedApiTransport`. Transport owns the HTTP client, transient session state,
CSRF headers, timeouts, error translation and connection notifications. Feature
methods retain their existing public signatures. Pages still receive the same
client instance. No feature introduces a second session or local collection
cache on disk.

The client does not import server code or database repositories. Presentation
may reuse standalone pure enums, formatting and media-selection components.
Collection writes always go through the server API; portable backup handling in
the browser transfers archives and does not restore a browser database.

## Server

`bin/shared_server.dart` composes `shared_server/app/shared_server_api.dart`.
The entry point keeps global origin, session and administrator guards, health
checks, exception translation and routing. Collection dispatch lives in
`collection/infrastructure/http/care_api.dart`.

| Layer | Responsibilities |
| --- | --- |
| `<feature>/infrastructure/http/` | Existing route and HTTP-method matching, bounded request decoding, response delivery and feature routing |
| `<feature>/application/` | Typed input validation, collection/account commands, conflict and lifecycle checks, backup operations and transaction orchestration |
| `<feature>/domain/` | API results/errors, account/session identity and allowlisted audit metadata |
| `<feature>/infrastructure/` | Account SQLite storage, password hashing, collection audit storage and audit DDL |
| `shared/infrastructure/` | Server database connection, HTTP readers/writers and existing response serialization |

Animal, Box, Feeding and Media handlers delegate commands to their feature
operations. Weight and Shedding commands live with Animals. Authentication,
Settings, account administration, Audit and Backups have their own modules.
Existing collection repositories in `core/database/repositories/` remain the
shared persistence implementation used by standalone and the server. This
refactor does not move them into the browser client or change their behavior.

One `CollectionOperationGate` is shared by collection routing, backups and audit
reads. One Feeding idempotency cache belongs to each `CareApi`; rollback and
successful collection replacement still clear it. The backup handler retains
session-bound safety grants and rechecks their collection generation after
draining writes. Restore and its successful audit event still commit in the
same collection transaction. Account commands retain the account store's
identity checks, session revocation and final-administrator protection.

Application modules accept plain command values and API results rather than
`HttpRequest` or Flutter widgets. Server persistence never depends on browser
presentation. Audit metadata excludes request bodies, secret values and notes.

## Incremental migration and verification

Former flat source paths remain as small compatibility exports. Production
imports and existing feature tests use the canonical feature paths. New code
should use those paths; compatibility files contain no duplicate implementation.
They can be removed in a later, explicit migration after consumers have moved.

Architecture tests reject browser dependencies on server persistence, HTTP/UI
dependencies in server application modules and new production imports through
the compatibility paths. A separate compatibility test verifies that old
imports resolve to the same public types. Existing UI and API regression tests
continue to exercise the behavior of the extracted modules.

See [architecture decisions](architecture-decisions.md),
[Shared Care API](shared-care-api.md),
[development](development.md) and
[project documentation](project-documentation.md).
