# Shared Care committed change contract (Issue #226)

## Scope

The server advertises committed collection changes through authenticated
`GET /api/v1/changes`. `SharedApiClient.queryChanges(since: appliedCursor)`
reads this contract, including bodyless HTTP 304 responses. The controller,
stream delivery and reconnect policy are tracked in #227, #228 and #229.

The production HTTP API remains the data and command interface. Change hints
contain resource kinds and IDs, never names, notes, pictures, credentials or
audit contents. Server data ownership and the existing write policy remain.

## Revision and audience

- Each SharedServerApi instance starts with a random epoch and revision zero.
- Each successful collection mutation publishes once, after its outer data and
  audit transaction commits. Failed writes, rolled-back transactions and
  idempotent Feeding/picture replays do not publish another collection revision.
- Grouped Feedings publish one hint covering all affected Animals.
- Successful collection replacement rotates the epoch once and clears replay;
  failed restore preserves the epoch. A new server process also has a new epoch.
- The backup gate's generation is separate. It still advances conservatively on
  mutation admission and continues to invalidate stale safety-backup grants.
- A cursor is opaque and scoped to immutable account identity and role. Numeric
  account-ID reuse cannot make another account's cursor valid.
- Personal preferences have their own persistent account-store revision. Their
  updates do not advance the collection revision or another account's cursor.
  Several changes coalesce into one `preferencesChanged` hint for the owner.
- Administrative audit-resource hints are omitted for caregivers. Account
  administration/rejected-audit bookkeeping is not a collection-data commit.

The process-local replay buffer retains 128 collection changes by default.
Each resource kind retains at most 128 IDs per change; larger sets become a
whole-kind invalidation. The buffer is transient and is not a durable event log.
No browser collection database or persistent change journal is introduced.

## Conditional query

Initial request:

```http
GET /api/v1/changes
```

Example response (the actual cursor is opaque):

```json
{
  "epoch": "<server-epoch>",
  "revision": 0,
  "preferencesRevision": 0,
  "cursor": "<opaque-cursor>",
  "reset": true,
  "reason": "missing_cursor",
  "preferencesChanged": true,
  "changes": []
}
```

After a snapshot has been applied, query from its cursor:

```http
GET /api/v1/changes?since=<URL-encoded-applied-cursor>
If-None-Match: "<applied-cursor>"
```

If the audience and cursor are valid and the validator still matches, the
server returns HTTP 304 with no body. Otherwise HTTP 200 contains the current
cursor and retained hints after `since`. Successful responses include ETag,
`X-Shared-Care-Cursor`, `Vary: Cookie` and `Cache-Control: private, no-store`.
Authentication and origin checks occur before evaluating the validator; an
expired session gets HTTP 401, never a cached HTTP 304.

`reset: true` means reconcile authoritative state. Reasons are `missing_cursor`,
`invalid_cursor`, `foreign_cursor`, `future_cursor`, `expired_cursor` and
`epoch_changed`. A reset contains no incomplete replay. During exclusive backup
ownership the endpoint returns authenticated HTTP 503 `restore_in_progress`.

The conditional client reader derives If-None-Match from the **applied** `since`
cursor. It does not silently store or advance an application cursor. An HTTP 304
must return the same cursor and is handled before JSON decoding. Scheduling
one foreground fallback query every 15 seconds belongs to #229.

## Resource IDs and dependencies

`changes` contains entries of the form:

```json
{
  "revision": 12,
  "resources": {
    "animals": [1, 2],
    "feedings": [25, 26],
    "feedingHistories": [1, 2],
    "reminders": [1, 2]
  }
}
```

| Kind | ID meaning |
| --- | --- |
| animals | Animal IDs; invalidate corresponding detail and list entries |
| boxes | Box IDs, including old and new assignments where applicable |
| feedings | Feeding IDs |
| feedingHistories | Animal IDs owning the histories |
| weightHistories | Animal IDs owning the histories |
| sheddingHistories | Animal IDs owning the histories |
| animalPictures | Animal IDs owning the galleries |
| boxPictures | Box IDs owning the galleries |
| media | Media IDs; null for a broad deletion invalidation |
| reminders | Animal IDs whose reminder/overview state may change |
| audit | Administrative audit listing, visible only to administrators |
| collection | Conservative whole-collection invalidation for a future mutation |

A null value invalidates the whole kind. An empty ID list affects no entries.
Hints may conservatively include unchanged dependencies; they are not patches.
Feedings invalidate the relevant Animals, histories and reminders without
invalidating their picture galleries. Explicit picture changes and changed
primary-picture pointers invalidate the owner gallery and affected media.
Parent deletion also invalidates dependent histories/media as appropriate.
Local clock-driven due states still need a client clock, without database writes.

## Snapshot races

Successful collection reads include `X-Shared-Care-Cursor-Before` and
`X-Shared-Care-Cursor`, captured around dispatch. Different values indicate that
advertised state changed while the response was built. Several HTTP reads do
not form an atomic database snapshot; equal fences on one response do not prove
that all other cached resources are current.

For initial loading/reconciliation, capture cursor C0, load required visible
resources/preferences, then query changes since C0. Refetch affected resources
if a later revision arrived. Advance the application-applied cursor only after
all corresponding reads succeed. A commit advertised just after a response is
still returned by the next query from the older cursor. The #227 controller
owns coalescing and this apply protocol. #229 keeps transport-received IDs
separate from the application-applied cursor during reconnect/replay.

## Persistence and compatibility

The private `accounts.sqlite` preferences table gains a revision column with
default zero. Existing preference values are preserved, and changed preference
values and their revision update in the same synchronous SQLite statement.
Unchanged preference patches do not advance that counter.

The portable collection format and Drift collection schema are unchanged.
Collection restore does not replace accounts or their preference revisions.
Collection hints cover writes through SharedServerApi; out-of-process database
editing is outside this process-local synchronization contract.

## SSE delivery (Issue #228)

`GET /api/v1/changes/events` uses the existing session cookie and the same origin
and fetch-site checks as `/changes`. URLs accept no query parameters. Cookies,
passwords and CSRF values never appear in URLs or frames. No CORS allowance is
added. A rejected admission returns the normal JSON 401/403 before streaming;
connection exhaustion returns 429 with `Retry-After: 15`.

A successful response is `text/event-stream; charset=utf-8`, private/no-store,
`Vary: Cookie`, nosniff. It has no collection read lease or backup gate ownership.
The Dart HTTP/1.1 upstream is dedicated and close-delimited: socket ownership
lets the server observe an idle peer FIN. Caddy translates this upstream response
for browser HTTP/2 while preserving cancellation and automatic SSE flushing.
Keep its default cancellation behavior: do not add `flush_interval -1`,
`response_buffers`, or response compression to the API route.

Each `changes` event has an `id` equal to the audience-scoped `cursor` and a JSON
`data` document with the same fields and authorization filtering as `/changes`.
`Last-Event-ID` is optional and bounded to 200 characters. Missing, invalid,
foreign, future, expired and old-epoch cursors receive the established reset
semantics. The initial frame without a cursor is a reset. Replay never contains
collection field values or another account's preference revision. A frame above
64 KiB is replaced by a small reset with reason `replay_too_large`.

Defaults: 32 connections/server, eight/account identity; the existing 128-commit
FIFO; at most one in-flight frame and one dirty bit per writer; a two-second
write deadline. Multiple commits while a writer is busy coalesce. Rebuild the
next frame from bounded history, or reset after a history gap. There is no queue
per committed event. A 15-second `keepalive` event with empty JSON data, without an `id` field,
keeps the path active, rechecks authentication and lets #229 observe liveness.
Unchanged non-periodic checks can still send comments. The browser may expose
its previously received ID on a keepalive MessageEvent; the client ignores that
ID and never treats keepalive as a data hint. Account/session changes trigger immediate revalidation;
a timer also revalidates at the session deadline. Revocation, deactivation,
password/role changes and deletion terminate affected subscriptions. A live
stream sends `auth-required` with an empty object before closing when possible;
transport failure may instead close the socket directly. Timers, subscriptions,
write deadlines and connection reservations are released on disconnect/shutdown.

The browser uses a separate, injectable native `EventSource` port rather than
buffered JSON requests. Its same-origin check prevents credentialed cross-origin
connections. It exposes connection/error/authentication states and
`lastReceivedId`. A received hint wakes #227's `reconcile()` from its existing
application-applied cursor. Only successful authoritative reads advance that
cursor; a transport event cannot acknowledge data. Native retry is closed on
errors, preventing an unauthorized source from repeatedly reconnecting.

#229 now owns the connection policy. Its initial snapshot queries revisions
before required reads, applies them, then queries again before opening SSE.
Open/reopen always reconciles from #227's application-applied cursor. Reset,
replay-gap, foreign/future cursor and epoch-change responses keep the same
conservative invalidation semantics. Received event IDs never become data cursors.

One controller/timer per tab coordinates streaming or conditional fallback.
Connection setup is bounded to eight seconds; missing observable activity for
45 seconds closes a silent stream. Healthy keepalives perform no data GET and
produce no resource invalidation. Failed probes back off with jitter in
22.5–30, 45–60 and 90–120 second windows, capped at 120 seconds. Thirty seconds
of healthy activity resets failure history. A successful authoritative HTTP
query after the previous failure must precede a new probe. The fallback timer
is cancelled before starting EventSource. Failed/rejected native sources close
the browser's implicit retry.

Unchanged fallback uses a single conditional query every 15 seconds (four per
minute); commands, explicit reloads, reconnect reconciliation and changed-data
post-read fences are accounted separately. There is no polling timer while SSE
is open/connecting. The same one-shot timer instead watches liveness/setup.
Hidden tabs and backup ownership stop the source and cancel scheduled work.
Resume checks the local due clock and reconciles before reconnecting, retaining
backoff. Failed restore retains the cursor; only successful local replacement
resets the scope and media identity before resuming reads.

Already-started HTTP reads drain without parallel replacement requests. Scope
and lifecycle generations reject late state/cursor application, retain dirty
work when interrupted, and isolate a new login. Late 401 responses cannot clear
a newer session. A `foreign_cursor` triggers session verification through the
existing authenticated session endpoint, without decoding the opaque cursor:
shared browser cookies may have changed account in another tab. Actual session
changes clear old cached home data and return protected routes to the root.
Network recovery preserves mounted forms and their drafts; it queues no writes.
A failed command remains unconfirmed until authoritative reads recover.

See the [#229 validation report](testing/shared-care-recovery-validation-2026-10-18.md)
for deterministic scheduling, session/restore cases and browser/gateway checks.
Target-device and long-term performance acceptance remain #230.

A successful collection replacement emits an epoch reset to open streams. Failed
restore and export emit no collection reset. This transport requires no schema,
backup-format, permission or cloud-service change.

## Verification

Tests cover bounded/foreign/future/epoch cursors, audience filtering, conditional
authentication/HTTP 304, concurrent commits, an external SQLite observer seeing
committed data before publication, read-fence races, grouped/idempotent Feedings,
audit rollback, media replay, metadata primary-picture changes, history and
lifecycle mutations, private preferences, legacy account migration and restore.

```bash
flutter test test/shared_server/committed_changes_test.dart \
  test/shared_server/shared_changes_test.dart \
  test/shared_client/shared_changes_api_test.dart
```

The [SSE issue review](testing/shared-care-sse-issue-review-2026-10-18.md)
maps the older overlapping issues onto #226-#230.
