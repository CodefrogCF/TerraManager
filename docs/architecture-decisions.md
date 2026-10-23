# Architecture Decision Records

Accepted decisions, with rationale and material trade-offs. Detailed fields,
routes and test results live in the linked references. Existing ADR numbers
remain stable; later migrations qualify earlier choices below.

## ADR-001: Local-first architecture

**Date:** 2026-08-19

Standalone stores its collection on the current device/browser and works
offline. This avoids a service dependency but makes external backups essential.
Shared Care is a separate self-hosted mode (ADR-030), not synchronization of
standalone databases.

## ADR-002: QR code as stable box identifier

**Date:** 2026-08-19

A Box receives an immutable `TM:BOX:<UUID-v4>` identifier. The QR contains
only this identifier; data changes do not invalidate a physical label. The
collection is still needed to resolve it, so a QR label cannot replace backup.

## ADR-003: Drift and SQLite as local database

**Date:** 2026-08-19

Use Drift over SQLite for typed relational queries, transactions, foreign
keys and migrations. Keep persistence behind repositories; review generated
schema changes and migration tests. See [Data model](data-model.md).

## ADR-004: SQLite WASM persistence on Web

**Date:** 2026-08-27

Use SQLite WASM with a compiled Drift worker for standalone Web. Storage is
origin/profile-specific; private browsing or cleared site data can lose it.
Ship matching worker/WASM assets and keep portable backups outside the browser.

## ADR-005: Platform-specific QR operations behind services

**Date:** 2026-08-27

Separate QR generation, validation, resolution and platform saving behind
services. Shared domain identifiers stay independent of camera/file APIs; test
platform adapters on the affected device/browser.

## ADR-006: Store UI preferences outside the domain database

**Date:** 2026-09-01

Standalone appearance/language/sorting preferences use `shared_preferences`
outside the domain schema. Portable settings are explicitly encoded in backups.
Shared Care preferences instead belong to each server account; device-local
archive preferences and account settings must not leak across users.

## ADR-007: Portable versioned backup format

**Date:** 2026-09-02

Use versioned portable JSON/media ZIPs instead of raw database copies.
Export format 2; retain import compatibility with formats 1/2 and explicit enum
encoding. Restore validates before full replacement. Schema and portable format
versions evolve independently. See [Backup format](backup-format.md).

## ADR-008: Store application media in persistent database-backed MediaAssets

**Date:** 2026-09-03

Store picture bytes/metadata in persistent MediaAssets rather than relying
on temporary picker paths. Migrate readable legacy pictures without losing
other records. This supports portable backups and consistent Android/Web storage.

## ADR-009: Preserve source ordering with contextual detail navigation

**Date:** 2026-09-04

Pass the visible overview ordering into detail navigation. Swiping follows
that context, including sorting/grouping, without changing record ownership.
Refresh the context when records change and preserve overview position on return.

## ADR-010: Store grouped feedings as atomic per-Animal events

**Date:** 2026-09-05

Group feeding creates one FeedingEvent per selected Animal in a single
transaction. Validate the active Box/Animal assignment again when committing;
failure must not leave a partially recorded group.

## ADR-011: Store feeding reminder configuration on each Animal

**Date:** 2026-09-08

Store reminder configuration on each Animal, shared by all views and
portable backups. Interval mode pairs a positive day interval with a baseline;
weekday mode adds selected days, local time and IANA zone (schema 17).

## ADR-012: Derive feeding reminder state from current history

**Date:** 2026-09-08

Derive reminder state from current feeding history, configuration and time.
Do not persist a competing due flag. Recompute after feeding/reminder changes
and as the clock advances, including foreground return.

## ADR-013: Present feeding reminders as derived, non-modal UI state

**Date:** 2026-09-08

Show due/future feeding information as non-modal in-app state. Navigation
indicators and overview summaries reuse the same calculation. This introduces
no notification permission or background delivery service.

## ADR-014: Adopt a permanent cross-platform application identity

**Date:** 2026-09-09

Use the permanent Android identity `com.codefrog.terramanager`. Identity
or signing changes affect the update/storage path; historical debug/temporary-ID
installations require backup transfer. See [Installation](installation-and-updates.md).

## ADR-015: Require external production credentials for Android Release builds

**Date:** 2026-09-09

Keep production signing credentials outside Git. Debug/CI must work
without them; Release must fail on missing/incomplete credentials. Preserve the
established certificate for direct updates. See [Signing](android-release-signing.md).

## ADR-016: License TerraManager under GPL-3.0-or-later

**Date:** 2026-09-09

License the project under `GPL-3.0-or-later`. Keep the license accessible
in the repository, site and app. Contribution terms preserve clear copyright
ownership and the possibility of separate licensing; see [CONTRIBUTING](../CONTRIBUTING.md).

## ADR-017: Pin reproducible public quality gates and keep signing private

**Date:** 2026-09-09

Pin Flutter/Java, dependency locks and CI action commits. Public checks
build Debug/Web and do not require production secrets. Toolchain upgrades need
explicit lock review and platform validation. See [Toolchain](toolchain-baseline.md).

## ADR-018: Preserve primary pages while navigating by swipe

**Date:** 2026-09-14

Preserve primary page state while switching navigation by swipe. Returning
to overviews should retain scroll and presentation state; explicit refreshes
and collection changes update data without recreating unrelated pages.

## ADR-019: Store extended Animal characteristics as optional text

**Date:** 2026-09-14

Optional extended Animal notes remain text and do not create unsupported
domain models. Later numeric weight and timestamped shedding histories replace
their free-form predecessors where migration is unambiguous; retain ambiguous
legacy values rather than inventing measurements/events.

## ADR-020: Render repository legal documents offline in Settings

**Date:** 2026-09-14

Render bundled repository privacy/license text inside Settings for offline
access. Published privacy copies must keep the same bodies as the root policies;
links to external services remain explicit user actions.

## ADR-021: Create independent records through overview quick actions

**Date:** 2026-09-15

Create independent records through overview quick actions. Duplicates get
new IDs and Box QR values, retain reusable data/pictures, and do not copy care
timelines or assigned Animals. Keep names editable through the edit forms.

## ADR-022: Generate selected Box QR documents locally before saving

**Date:** 2026-09-15

Generate selected Box QR PNG/ZIP/PDF bytes locally, then use the existing
platform save workflow. Keep selection, physical PDF geometry, cancellation and
filename handling explicit. The same local generation/save boundary is used
by Animal profile PDFs; no external rendering service is required.

## ADR-023: Store stable Animal taxonomy and derive overview groups

**Date:** 2026-09-15

Persist stable category/subcategory values; derive localized overview groups
without storing translated labels. Validate compatible pairs and keep grouping
independent of sort direction. Older records default to `other`.

## ADR-024: Store temperature-zone notes on Boxes

**Date:** 2026-09-15

Store free-form temperature-zone notes on the Box, where enclosure-specific
information belongs. Migrate compatible legacy Animal values; omit empty rows
from details and preserve values through duplication/backups.

## ADR-025: Prioritize actionable Animal data and derive Box volume

**Date:** 2026-09-16

Prioritize actionable Animal care information. Derive Box volume from
complete positive dimensions instead of storing a second value. Keep incomplete
volumes last and ordering deterministic in either direction.

## ADR-026: Render the project homepage from shared localized static content

**Date:** 2026-09-16

Build the German/English homepage from shared static Jekyll layouts/data.
Use project-base-path-aware links, bundled assets, accessibility/SEO metadata
and no tracking/external scripts. Guides and privacy remain locally reachable.

## ADR-027: Store Animal shedding history as owned event records

**Date:** 2026-09-22

Store shedding as owned timestamped events with optional notes and CRUD.
Preserve history while archived and in backups; migrate compatible legacy notes
deterministically. See the current [data model](data-model.md).

## ADR-028: Store Animal detail visibility per record

**Date:** 2026-09-22

Store independent `showWeightOnDetail` / `showSheddingOnDetail` flags on the
Animal, default true. Hiding a section affects presentation only and preserves
history. Shared Care users see the same record-level choice.

## ADR-029: Reuse local Box QR resolution for transactional Animal reassignment

**Date:** 2026-09-22

Reuse local Box QR validation for confirmed transactional reassignment.
Reject unknown, archived and current destinations; recheck active assignment
inside the write transaction. Cancel/failure leaves the previous Box unchanged.

## ADR-030: Keep shared collection data on a self-hosted server

**Date:** 2026-09-23

Use one self-hosted server-owned collection and local accounts for Shared
Care. Browsers use an authenticated same-origin HTTPS API; standalone collections
remain independent. Keep account/collection databases on protected local storage.
This provides multi-caregiver access without a cloud broker or native permission.

## ADR-031: Decode Shared Care Box QR codes in the browser without a public CDN

**Date:** 2026-09-24

Decode Shared Care Box QR labels locally with the browser's native
BarcodeDetector. Send only the validated identifier to the server. Require
trusted HTTPS/camera support; retain manual selection when scanning is unavailable.
Do not load a decoder from a public CDN.

## ADR-032: Commit Shared Care changes with server-owned audit metadata

**Date:** 2026-09-26

Commit allowlisted audit metadata with each collection/account mutation;
audit failure rolls back the mutation. Retain attribution for 365 days through
account deletion/portable restore. Exclude notes, pictures and credentials;
host-volume backups protect audit separately from portable collections.

## ADR-033: Manage server accounts without deleting audit attribution

**Date:** 2026-09-26

Manage local accounts with stable audit identities, role/active-state
checks and session revocation. Protect the last active administrator inside the
transaction, including after password hashing. Removal deletes credentials/
sessions, not collection history or retained attribution.

## ADR-034: Read administrator audit metadata with bounded merged pagination

**Date:** 2026-09-27

Expose metadata-only administrator audit with bounded merged seek
pagination over account/collection sources. Keep filters with opaque cursors;
reading must not disclose payloads or create another audit event. See [API](shared-care-api.md).

## ADR-035: Organize Shared Care by feature with explicit transport and persistence boundaries

**Date:** 2026-09-27

Organize client/server code by feature with explicit presentation,
application, domain and infrastructure boundaries. HTTP handlers delegate to
typed operations; clients cannot depend on persistence. Retain old imports as
export-only adapters during migration. See [Code organization](shared-care-architecture.md).

## ADR-036: Password-encrypted backups and large-file memory

**Date:** 2026-09-28

Use an optional versioned authenticated outer container around the portable
ZIP: Argon2id plus framed AES-256-GCM with fresh salt/nonce, authenticated metadata
and a final frame. Keep legacy ZIP imports and the combined wrong-password/
damage error. Never persist passwords; Shared Care encrypts/decrypts client-side.

Protected operations still use memory proportional to the archive. File-backed
and incremental paths reduce copies without establishing end-to-end bounded
memory. See [container format](backup-format.md).

## ADR-037: Evaluate versioned Shared Care invalidation and SSE delivery

Use SSE for authenticated one-way invalidations, targeted HTTP reads for
data, and conditional/version polling as fallback. Writes remain on the existing
HTTP API. This reduces redundant reads without adding a second command protocol,
a cloud service or a native permission.

| Option | Advantage | Drawback |
| --- | --- | --- |
| Existing full polling | Simple baseline | Repeated payloads and interval latency |
| Conditional/version polling | Cheap unchanged responses | Request/interval overhead remains |
| Long polling | Prompt changes over HTTP | Held requests, timeout/renewal/cancellation |
| SSE | Fits one-way hints and HTTP/browser infrastructure | Replay, authentication, lifecycle and connection limits |
| WebSockets | Bidirectional channel | Extra protocol although commands already use HTTP |

Publish only committed data/audit changes. Separate application-applied cursors
from received event IDs; bound replay, writers and connections. Reconcile on gaps,
restart, restore and foreground return; preserve drafts, conflicts and the offline
write policy. Enforce cookie/origin/role/session checks throughout open streams.
The [change contract](shared-care-change-contract.md) defines exact behavior.

Issues #226-#229 implement revisions, targeted refresh, SSE and recovery.
Deployments must verify the Dart/Caddy/browser path, authentication, reconnects
and resource use on their own hardware.

## ADR-038: Opt-in local Android feeding notifications

**Date:** 2026-10-22

Use pinned `flutter_local_notifications` 22.3.2 with inexact one-shot Android
alarms, one localized channel and generic private content. Request notification
permission only after explicit device opt-in; do not request exact alarms or
battery exemptions. Web and Shared Care retain in-app reminders only, avoiding
extra alerts from several browser clients and requiring no server connection.

Reuse `FeedingReminderService` for interval and IANA weekday/DST calculations.
Observe committed Animal/Feeding changes; reconcile on startup, app resume,
language and device-setting changes. The plugin restores pending UTC instants
on boot/update. A device-only appointment ledger prevents re-notifying consumed
appointments; it and opt-in are excluded from portable backups. In-app 24-hour
suppression remains independent. Validate payload version, collection, record
creation identity and appointment before navigating; never replace an edit route.

Inexact delivery can be delayed or blocked by Android, force stop, channel or
manufacturer limits. Surface planning failures and retry; do not claim reliable
real-time delivery.
