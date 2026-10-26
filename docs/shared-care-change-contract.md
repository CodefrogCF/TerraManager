# Shared Care change contract

Implemented by Issues #226-#229. HTTP remains
the authorized command/data interface. Change hints carry resource kinds/IDs,
never record contents or credentials.

## Committed revisions and conditional reads

- Each API process starts a random epoch and revision zero. A successful outer
  data/audit transaction publishes once after commit. Rollback and idempotent
  replay publish nothing; grouped Feedings publish one combined hint.
- Successful restore rotates the epoch and clears replay. Failed restore does
  not. The backup gate generation is separate and must not be used as a cursor.
- Opaque cursors are scoped to immutable account identity and role. Preferences
  have their own persistent revision and notify only their owner; audit hints
  are administrator-only.
- Replay retains 128 commits by default. Each kind retains at most 128 IDs per
  commit; larger sets invalidate the whole kind. This is not a durable event log.

`GET /api/v1/changes` returns:

```json
{"epoch":"...","revision":0,"preferencesRevision":0,"cursor":"...",
 "reset":true,"reason":"missing_cursor","preferencesChanged":true,"changes":[]}
```

After applying data, send `?since=<encoded-applied-cursor>` and
`If-None-Match: "<applied-cursor>"`. A valid unchanged audience receives bodyless
304; changed state receives 200. Responses use ETag, `X-Shared-Care-Cursor`,
`Vary: Cookie`, `Cache-Control: private, no-store`. Authentication/origin checks
precede validators; expired sessions receive 401. Restore ownership returns 503.

`reset` requires reconciliation for `missing_cursor`, `invalid_cursor`,
`foreign_cursor`, `future_cursor`, `expired_cursor` or `epoch_changed`; incomplete
replay is never presented as complete.

## Invalidation and application

| Resource kind | ID meaning |
| --- | --- |
| `animals`, `boxes`, `feedings`, `media` | Respective record IDs |
| `boxCareHistories` | Owning Box IDs; care changes do not invalidate Animal histories |
| `feedingHistories`, `weightHistories`, `sheddingHistories`, `reminders` | Owning Animal IDs |
| `animalPictures`, `boxPictures` | Gallery owner IDs |
| `audit` | Administrator listing |
| `collection` | Conservative whole-collection invalidation |

Each change has `revision` and a `resources` map. Null means the entire kind;
an empty ID list means none. Hints are invalidations, not patches. Refresh
visible affected resources and mark hidden ones stale. Include old/new Box
assignments and history/reminder dependencies; a Feeding alone must not reload
unchanged pictures. Keep the local due-state clock active independently.

Reads carry `X-Shared-Care-Cursor-Before` and `X-Shared-Care-Cursor` fences.
Different values signal a race; several reads are not an atomic snapshot.
Capture C0, read required data/preferences, then query since C0 and reconcile
intervening changes. Advance the application-applied cursor only after successful
reads. Coalesce concurrent refreshes and reject stale scope/lifecycle responses.
Keep transport-received event IDs separate from this applied cursor.

## SSE delivery

`GET /api/v1/changes/events` uses the existing same-origin session cookie;
query parameters/credentials in URLs are rejected. Before streaming, normal
401/403 apply; exhaustion returns 429 with `Retry-After: 15`.

- Response: `text/event-stream; charset=utf-8`, private/no-store, nosniff,
  `Vary: Cookie`. It holds no database transaction or backup lease.
- `changes` frames carry JSON from the conditional contract, with `id: cursor`.
  Optional `Last-Event-ID` is bounded to 200 characters. Oversized replay above
  64 KiB becomes a `replay_too_large` reset.
- Limits: 32 streams/server, eight/account, one in-flight frame plus one dirty
  bit per writer, two-second write deadline. Busy writers coalesce from bounded
  history rather than queuing one item per commit.
- An empty-JSON `keepalive` every 15 seconds has no ID and triggers no data reads.
  Revalidate at expiry and on account/session changes. Revocation sends
  `auth-required` when possible, then closes. Disconnect/shutdown releases timers,
  subscriptions and reservations.
- The dedicated, close-delimited Dart HTTP/1.1 upstream observes peer shutdown;
  Caddy serves browser HTTP/2 and flushes SSE automatically. Keep default
  cancellation: no `flush_interval -1`, `response_buffers` or API compression.

## Recovery policy

One synchronization controller and one timer per tab coordinate SSE or fallback.
Reconcile before opening/reopening. Setup deadline is eight seconds; 45 seconds
without observable activity closes a silent connection. Failed probes back off
with jitter in 22.5-30, 45-60 and 90-120-second windows, capped at 120 seconds;
30 healthy seconds reset failure history. An authoritative successful HTTP
query precedes the next probe. Close native EventSource retry on failure.

Fallback uses one conditional read every 15 seconds; healthy/connecting SSE has
no polling timer. Commands, manual reload and race/reconnect reads are separate.
Hidden tabs and backup ownership pause work. Resume recomputes due state,
reconciles and reconnects while retaining backoff. Successful replacement resets
scope/media identity; failed restore preserves it.

Already-started reads drain without overlapping replacement work. Generations
isolate late responses and new logins; a late 401 must not sign out a newer
session. A foreign cursor verifies the session instead of decoding the cursor.
Actual account changes clear cached protected views. Network recovery preserves
mounted drafts and queues no writes; uncertain saves require authoritative checks.
