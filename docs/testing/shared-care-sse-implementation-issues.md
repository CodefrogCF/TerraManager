# Implementation issue drafts following #186

SSE was selected on 2026-10-18. These are copyable drafts; no GitHub issues have
been created. Performance figures below are acceptance targets, not claims that
the production implementation already meets them. The current real Flutter
baseline is approximately 12 overview / 40 detail-stack GETs per minute/client.
The [corrected three-repetition Pi lab](shared-care-sse-comparison-2026-10-18.md)
completed with 173-180 ms SSE p95, zero idle data GETs and about 99.98% fewer idle
received body bytes. These are lab results; production targets remain below.

## 1. Shared Care: publish committed resource revisions and conditional change queries

**Scope:** Shared Care server and API contract
**Priority:** High
**Type:** Feature / architecture

### Description

Introduce the committed-change contract needed by the synchronization controller
and SSE. Expose an authenticated conditional revision query that also serves as
the polling fallback. Keep the existing backup-safety generation separate.

### Acceptance criteria

- [ ] Define epoch/revision, affected resource identifiers, user-scoped hints and snapshot/revision consistency.
- [ ] Publish only after a successful commit; failed or rolled-back writes publish no change.
- [ ] Cover Animals, Boxes, Feedings, weights, shedding, media, archive/restore/deletion, preferences and successful collection replacement.
- [ ] Grouped operations publish a consistent committed change; idempotent replay does not invent another data change.
- [ ] Keep a bounded replay window and explicit reset semantics for missing, old, foreign or future cursors and server/restore epoch changes.
- [ ] Support authenticated HTTP 304 before JSON decoding. Unchanged fallback uses at most four revision queries/minute/foreground tab at the 15-second interval.
- [ ] Preserve existing authentication, roles, CSRF, expectedRevision conflicts, audit atomicity, backup gates and local data ownership.
- [ ] Test concurrent commits, snapshot races, grouped/idempotent operations, rollback and collection replacement.

## 2. Shared Care: replace screen polling with a central targeted refresh controller

**Scope:** Shared Care Flutter client
**Priority:** High
**Type:** Feature / performance

### Description

Create one transient synchronization controller per signed-in browser tab. Use
revision changes to refresh affected visible resources and mark hidden resources
stale. Remove independent screen polling after equivalent recovery is available.

### Acceptance criteria

- [ ] Define dependencies between latest Feeding, histories, reminders, Animal/Box lists, galleries and former/new Box assignments.
- [ ] Coalesce bursts and local command acknowledgements with stream hints while retaining changes from another device using the same account.
- [ ] Unchanged revisions and heartbeats cause zero collection-data GETs and no data-dependent list replacement.
- [ ] Unchanged Animal details do not reload gallery metadata on every refresh; retain existing image caching.
- [ ] Preserve scroll position, route context, selected Animal, unsaved forms and the existing offline-write policy.
- [ ] Recompute clock-driven Feeding due states on schedule/resume without waiting for a database write.
- [ ] Apply a revision only after the corresponding reads succeed; reconcile changes arriving during an outstanding refresh.
- [ ] Add deterministic controller/widget coverage for invalidation, no-change cases, overlapping refreshes and gallery preservation.

## 3. Shared Care: deliver authenticated change notifications through SSE

**Scope:** Dart server, browser transport and Caddy integration
**Priority:** High
**Type:** Feature

### Description

Use one same-origin SSE connection per browser tab to deliver committed change
hints. Keep commands and data reads on the existing authorized HTTP API.

### Acceptance criteria

- [ ] Use the existing secure session cookie; keep credentials and CSRF tokens out of stream URLs and event payloads.
- [ ] Filter collection, account and administrative hints according to the subscriber's permissions.
- [ ] Revalidate open subscriptions on expiry/revocation; terminate unauthorized subscriptions without reconnect/login loops.
- [ ] Provide a browser EventSource adapter behind a testable Dart interface, independently of the buffered JSON transport.
- [ ] Bound active connections, replay retention and slow-consumer queues; release resources on disconnect.
- [ ] Keep long-lived streams outside collection transactions and exclusive backup ownership; publish reset only after successful restore.
- [ ] Verify trusted HTTPS and streaming through the existing Caddy gateway.
- [ ] With five LAN clients, target p95 visible update latency <= 2 seconds, >= 90% fewer idle data GETs and >= 80% fewer idle received bytes including upkeep versus polling.
- [ ] Keep laboratory DOM, actual Flutter semantics/frame measurements and physical-browser results distinct.

## 4. Shared Care: reconcile SSE reconnects, browser lifecycle and polling fallback

**Scope:** Shared Care synchronization lifecycle and recovery
**Priority:** High
**Type:** Reliability

### Description

Recover authoritative collection state after disconnects, foreground resume,
server restart and restore, while preserving edits and preventing duplicate
subscriptions. Use conditional/version polling when streaming is unavailable.

### Acceptance criteria

- [ ] Keep transport-received event IDs separate from the application-applied cursor.
- [ ] Reconcile on reconnect/resume; replay retained changes or reset/reload after gaps, unknown cursors and epoch changes.
- [ ] Handle restored/reused record/media IDs and changes arriving during initial snapshot loading.
- [ ] Use bounded retry backoff with jitter and prevent reconnect storms across tabs.
- [ ] Permit at most one active SSE connection or one fallback polling schedule per tab; avoid overlapping refresh loops.
- [ ] Fallback uses at most four unchanged version queries/minute/foreground tab; report its separate latency budget.
- [ ] Reduce hidden-tab work and reconcile promptly on resume without overwriting unsaved forms.
- [ ] Test outages, duplicate/out-of-order events, several tabs, login/logout, account revocation and successful/failed restore.

## 5. Shared Care: validate SSE performance and resource bounds on Raspberry Pi

**Scope:** Performance evaluation and regression coverage
**Priority:** Medium
**Type:** Testing / performance

### Description

Validate the production implementation against the recorded polling baseline.
Keep the comparative pilot, actual Flutter measurements and reliability results
separate, with reproducible workloads and explicit uncertainty.

### Acceptance criteria

- [ ] Repeat polling/SSE at five clients first; then cover 1/3/5/10 clients, overview/details, idle/writes, with at least three repetitions per relevant case.
- [ ] Confirm p95 visible update <= 2 seconds, >= 90% fewer idle data GETs and >= 80% fewer received bytes including upkeep while SSE is connected.
- [ ] Report per-trial p50/p95 and repetitions separately; avoid treating correlated client observations as independent trials.
- [ ] Record Dart/Caddy cumulative process CPU and sampled RSS separately, including coverage, restart identity and resource-sampler overhead.
- [ ] Validate proposed same-fixture budgets after warmup: Dart/Caddy mean idle CPU <= 0.10/0.10% of one core, write-window CPU <= 1.50/0.25%, maximum sampled PID 1 RSS <= 256/80 MiB. These have headroom above the lab observations and are not production passes.
- [ ] Run the fixed workload for 30 minutes and at least 100 reconnects after warmup; investigate a final warm 10-minute median RSS > 10% above the initial warm 10-minute median. Verify bounded queues and distinguish login/setup from connected operation.
- [ ] Include stream upkeep, resynchronization, fallback and physical browser background/foreground behavior.
- [ ] Retain the independent control reproducing ERR_ABORTED after complete no-store/manual-stream reads; classify remaining actual Flutter terminal events using body/application outcomes, without assuming every event is harmless.
- [ ] Capture real Flutter data-dependent build/frame behavior, preserving the distinction from laboratory DOM and semantic timestamps.
- [ ] Keep sanitized evidence and reproduction commands; exclude credentials, cookies, personal collection bodies and original HAR captures.
