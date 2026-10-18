# Consolidated Shared Care implementation issues

Use the existing issues #226-#230. Their bodies below separate server state,
client refresh, streaming, connection policy and production validation.
Checkboxes are left open for the operator to update after applying the code.

## #226 — Shared Care: publish committed resource revisions and conditional change queries

**Scope:** Shared Care server, change-query contract and conditional API reader
**Priority:** High
**Type:** Feature / architecture

### Description

Provide committed revisions and minimal resource invalidations as the foundation
for #227-#229. Keep synchronization revisions separate from the existing backup
safety generation. Personal preference updates must remain private to their owner.

### Acceptance criteria

- [ ] Publish exactly once after the outer data/audit transaction commits; rejected or rolled-back writes publish nothing.
- [ ] Cover Animals, Boxes, reminders, Feedings, weights, shedding, media, primary-picture changes, archive/restore/deletion and successful collection replacement.
- [ ] Grouped Feedings produce one consistent hint; Feeding and picture idempotency replays produce no additional revision.
- [ ] Define opaque audience-scoped cursors, restart/restore epochs, bounded replay and explicit reset semantics for missing, invalid, foreign, future and expired cursors.
- [ ] Track private preference revisions without advancing another account's cursor; preserve existing preferences when upgrading the private account database.
- [ ] Provide an authenticated conditional change query with ETag and bodyless HTTP 304; validate origin, session and audience before returning 304. The API reader handles 304 before JSON decoding.
- [ ] Define resource-ID semantics and snapshot/read-fence consistency so #227 can reconcile concurrent changes without prematurely advancing its applied cursor.
- [ ] Preserve roles, CSRF, expectedRevision conflicts, audit atomicity, backup gates, portable backup compatibility and local data ownership.
- [ ] Test concurrency, commit visibility, snapshot races, grouped/idempotent operations, rollback, account migration and successful/failed restore.

### Scope boundary

UI refresh orchestration belongs to #227, streaming to #228 and the 15-second
fallback schedule to #229. These features are not required to expose this API.

## #227 — Shared Care: replace screen polling with a central targeted refresh controller

**Scope:** Shared Care Flutter state and refresh orchestration
**Priority:** High
**Type:** Feature / performance

Implementation is included in the #227 source delivery. See the
[validation and integration boundary](shared-care-targeted-refresh-validation-2026-10-18.md).

### Description

Build one transient synchronization controller per signed-in browser tab using
the contract from #226. Refresh affected visible resources, mark hidden resources
stale and preserve unchanged UI state. Keep transport and connection policy
behind an interface for #228 and #229.

### Acceptance criteria

- [x] Define dependencies for Animal/Box lists and details, latest Feeding, histories, reminders, galleries and old/new Box assignments.
- [x] Coalesce invalidations and overlapping refreshes; retain changes from another device signed in to the same account when coalescing local acknowledgements.
- [x] Apply a cursor only after its required reads succeed; reconcile changes arriving during initial loading or an outstanding refresh.
- [x] Unchanged revisions and heartbeats cause no collection-data GETs or data-dependent list replacement.
- [x] Feeding-only updates retain gallery metadata and image caches; invalidate pictures only when their dependencies change.
- [x] Preserve scroll, route, selection and unsaved forms; replace independent screen polling once the shared refresh source provides equivalent update coverage.
- [x] Update clock-driven Feeding due states without database writes; expose a resume/reconcile operation for #229.
- [x] Add deterministic controller/widget tests for dependencies, burst coalescing, failed/overlapping reads and stable unchanged state.

### Scope boundary

This controller owns resource freshness and the application-applied cursor.
EventSource delivery belongs to #228; retry, fallback switching and browser
lifecycle scheduling belong to #229.

## #228 — Shared Care: deliver authenticated change notifications through SSE

**Scope:** Dart stream endpoint, browser EventSource adapter and Caddy integration
**Priority:** High
**Type:** Feature

### Description

Deliver #226 change hints through one same-origin SSE connection per browser tab.
Keep commands and authoritative reads on the existing HTTP API. Provide transport
events to #227 and connection-state signals to #229.

### Acceptance criteria

- [x] Use the existing Secure/HttpOnly/SameSite cookie; check origin and permissions. Put no password, cookie or CSRF value in stream URLs or event payloads.
- [x] Deliver minimal authorized hints and reset semantics; filter private preferences and administrative resources for the current audience.
- [x] Revalidate open sessions on expiry/revocation and stop unauthorized subscriptions without login/reconnect loops.
- [x] Provide a testable browser EventSource adapter, independently of buffered JSON requests; handle fragmented delivery and expose transport IDs without treating them as applied data.
- [x] Bound connections, replay and slow-consumer queues; cancel timers/subscriptions and release stream slots after disconnect, including through Caddy.
- [x] Keep streams outside collection transactions and exclusive backup ownership; deliver a reset after successful replacement and none after a failed restore.
- [x] Verify trusted HTTPS, Caddy flushing and supported HTTP/browser paths; retain automated reconnect/disconnect resource tests.
- [x] Feed the production measurements in #230; the existing laboratory prototype is not this implementation.

Implementation and local evidence:
[#228 validation](shared-care-sse-delivery-validation-2026-10-18.md).
Chrome/Edge, explicit local test-certificate trust and HTTP/1.1/HTTP/2 are covered.
Physical-browser/OS-trust and Pi performance acceptance remain in #230.

### Scope boundary

The adapter provides streaming and connection/error signals. Application retry
backoff, foreground policy, replay reconciliation and fallback switching belong
to #229.

## #229 — Shared Care: reconcile SSE reconnects, browser lifecycle and polling fallback

**Scope:** Synchronization connection policy, browser lifecycle and recovery
**Priority:** High
**Type:** Reliability

### Description

Coordinate #227 and #228 so authoritative state converges after outages, resume,
restart and restore. Use #226 conditional queries when streaming is unavailable,
without duplicate subscriptions or overlapping polling/refresh loops.

### Acceptance criteria

- [x] Keep transport-received IDs separate from #227's application-applied cursor; reconcile from successfully applied state after reconnect/resume.
- [x] Replay retained hints or reconcile after gaps, foreign/future cursors and epoch changes, including reused record/media IDs after restore.
- [x] Handle changes arriving during connection setup, initial snapshot loading and outstanding reads.
- [x] Use bounded retry backoff with jitter; prevent reconnect storms and repeated login attempts after expiry/revocation.
- [x] Maintain at most one active SSE connection or one fallback polling schedule per tab. At a 15-second interval, unchanged fallback uses at most four conditional revision queries/minute/foreground tab.
- [x] Reduce hidden-tab work, reconcile on resume and restore SSE gradually after fallback; trigger #227's clock-dependent refresh as needed.
- [x] Preserve unsaved edits, authentication, conflicts and the existing connected-state write policy; add no offline write queue.
- [x] Test outages, duplicate/out-of-order events, several tabs, login/logout, revocation and successful/failed restore with deterministic scheduling.

Implementation and controlled-clock evidence: [#229 validation](shared-care-recovery-validation-2026-10-18.md).
The physical-browser/device and performance matrix remains #230.

## #230 — Shared Care: validate SSE performance and resource bounds on Raspberry Pi

**Scope:** Production Flutter/device performance and regression acceptance
**Priority:** Medium
**Type:** Testing / performance

### Description

Validate the integrated #226-#229 implementation against the recorded real Flutter
polling baseline. Retain the completed laboratory comparison as reference evidence,
with its limits: five logical clients, laboratory DOM, and no demonstrated
per-mode RAM saving or long-term memory bound.

### Acceptance criteria

- [ ] Measure real Flutter API traffic and data-dependent build/frame behavior; keep laboratory DOM and semantics timestamps separate from paint/frame measurements.
- [ ] Repeat identical overview/detail, idle/write workloads at 1/3/5/10 clients with at least three repetitions; record physical desktop/mobile browsers, several tabs and trusted HTTPS.
- [ ] With five connected LAN clients, confirm p95 visible update <= 2 seconds, >= 90% fewer idle data GETs and >= 80% fewer idle received bytes including upkeep versus polling.
- [ ] Include stream upkeep, resynchronization and fallback traffic; report per-trial p50/p95 without treating correlated clients as independent repetitions.
- [ ] Record Dart/Caddy process CPU and RSS separately, with probe coverage and process identity. Proposed same-fixture warm budgets: idle CPU <= 0.10/0.10% of one core, write-window CPU <= 1.50/0.25%, sampled RSS <= 256/80 MiB. Validate these proposed budgets during integration.
- [ ] After warmup, run the fixed workload for 30 minutes and at least 100 reconnects. Investigate a final warm 10-minute median RSS > 10% above the initial warm 10-minute median; verify bounded queues and separate login/setup costs.
- [ ] Validate background/foreground, outage, session expiry and restore behavior on physical browsers, alongside #229's deterministic recovery tests.
- [ ] Classify actual Flutter terminal request failures using body/application outcomes. Retain the independent complete-body/no-store ERR_ABORTED control without assuming every earlier abort was harmless.
- [ ] Keep reproducible sanitized evidence and update ADR budgets/tolerances; exclude credentials, cookies, personal collection bodies and original HAR captures.

Preparation is available in the [integrated acceptance runbook](shared-care-integrated-acceptance.md): a disposable fixture with the current production API/SSE, the installed Flutter web image, process capture and repeated real-UI workloads. This preparation does not mark any Pi performance or physical-browser criterion passed.
