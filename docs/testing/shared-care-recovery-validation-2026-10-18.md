# Shared Care recovery and fallback — Issue #229

Date: 2026-10-18. Baseline: `16d0a15c4e83dfe856b3ea62d578e50f62dee426`.

## Scope and policy

`SharedSyncController` replaces the home page's interim polling/SSE scheduling.
One transient instance per API/tab owns one cancellable timer and at most one
native EventSource. There is no cross-tab collection store, cloud dependency,
automatic login or offline write queue.

| State | Scheduled work and transition |
| --- | --- |
| Initial/reconciling | Query revisions before initial visible reads; read required resources and query again before acknowledging their cursor |
| Connecting | Cancel fallback schedule; allow up to 8 seconds for native open |
| Streaming | Reconcile at open and on new hints; keep one 45-second activity deadline; no periodic revision query |
| Fallback | One conditional query per 15 seconds while unchanged; after a successful query, permit a jittered SSE probe when its deadline arrives |
| Hidden/backup | Close streaming, cancel connection/poll/retry/activity scheduling and pause the due clock; already-started reads drain behind generation guards |
| Resume | Update the due clock and reconcile authoritative state; retain retry history and reopen only when eligible |
| Authentication required | Close streaming and all scheduled work; wait for a new authenticated session |

Retry ceilings are 30, 60 and 120 seconds, each with an independent 75–100% jitter
window per tab (22.5–30, 45–60, 90–120 seconds). They remain capped at 120 seconds.
Thirty seconds of stable observable activity resets failure history. A successful
authoritative query after failure is required before another probe; expired or
revoked sessions therefore cannot sustain repeated EventSource or login attempts.
Default scheduling deadlines use elapsed monotonic time, separately from the
wall clock used for feeding due states. Tests inject their own clock/scheduler.

The server's existing 15-second upkeep is now an observable `keepalive` event
with an empty object and no `id` field. It does not change a revision or refresh
any collection data. Other unchanged checks can remain comments. The browser may
report its previous event ID on a keepalive MessageEvent; that ID is ignored.
A connection without observable activity for 45 seconds is closed and reconciled
through fallback. Old clients safely ignore the additional event type.

The [change contract](../shared-care-change-contract.md#sse-delivery-issue-228)
and ADR-037 describe the current wire protocol and recovery ownership.

## Cursor, lifecycle and session correctness

- Received IDs remain transport metadata. Reconciliation always starts at #227's
  successfully applied cursor. Duplicate/older events cannot acknowledge data
  or move that cursor backwards.
- Initial loading, connection setup and outstanding reads are fenced by a
  post-read query. Existing server reset semantics cover history gaps,
  foreign/future cursors, restart and replacement epochs.
- A new session or successful local replacement invalidates its scope/media
  generation. Pauses preserve the applied cursor and dirty work. Generation
  guards reject late state and prevent chained reads from starting after pause.
  Old work drains before replacement reads, without overlapping data refreshes.
- Only successful replacement resets local media identity; failed restore or
  backup export pauses/reconciles without inventing a new collection epoch.
- A late JSON, binary or streaming-download 401 cannot revoke a newer login.
  Late restore-session and logout responses cannot replace the next login.
- A foreign-audience response verifies the authenticated session without parsing
  its opaque cursor. This handles cookies changed by another tab when the next
  reconciliation occurs. Account changes clear cached home data and protected
  subroutes; they do not carry old-account drafts into the next session.
- Normal network/lifecycle recovery preserves mounted form drafts and conflicts.
  A failed command remains unconfirmed; an empty route refresh cannot mark it
  connected or silently retry the write. The home adapter also forwards transport
  failures from API calls outside the refresh loop, including uploads, into the
  same recovery policy.

## Automated validation

Toolchain: Flutter 3.47.2 / Dart 3.13.2, Windows x64; existing dependency lock.
The dependency graph was resolved offline. The host's existing plugin symlink
prerequisite prevents the last `pub get` step, so checks use the resolved graph
with `--no-pub`; no system setting was changed.

```sh
flutter analyze --no-pub
flutter test --no-pub test/shared_client test/shared_server \
  test/architecture/shared_care_boundaries_test.dart --reporter expanded
flutter build web --no-pub --target lib/main_shared.dart --no-web-resources-cdn
dart build cli --target=bin/shared_server.dart --output=/tmp/tm229/server
```

| Gate | Result |
| --- | --- |
| Full `flutter analyze --no-pub` | No issues found |
| Shared Care client/server and architecture regression | 292 passed |
| New controlled-clock policy tests | 19 passed as part of the regression |
| Actual `lib/main_shared.dart` web release, local web resources | Passed, including Wasm dry run |
| Native `bin/shared_server.dart` CLI bundle | Passed with SQLite native asset |
| Actual production handler/compiled web adapter through Caddy HTTPS | 40 repeated connection cycles; zero retained streams after each close |
| Periodic observable upkeep through Caddy | Received without a collection write in both Chrome and Edge; zero retained streams after close |

The new policy tests use an injected clock and timer queue: long intervals and
failure sequences run deterministically, without real sleeps or network timing.
They cover:

1. Initial/outstanding read races, serial reads and changes during setup.
2. Duplicate/out-of-order transport IDs and applied-cursor ownership.
3. Epoch/history resets and media identity reuse.
4. Four unchanged fallback queries per minute and one active timer/source.
5. Outages, slow queries, setup timeout and silent streams.
6. Jittered retries, repeated flapping, the 120-second cap and stable reset.
7. Ten minutes of healthy keepalives without idle data queries.
8. Hidden/backup suspension, foreground clock reconciliation and late reads.
9. Logout/login isolation, terminal authentication and initial unauthorized SSE.
10. Successful/failed replacement and independent tabs using the same account.
11. Unconfirmed commands remaining disconnected after a no-op route refresh.

Additional API tests cover late 401s for all response surfaces, pending logout/
session restore and shared-cookie audience changes. The actual widget test keeps
a Box draft through outage, background/resume, backoff and SSE return, then
refreshes the changed hidden overview when the draft is closed. Existing
Shared Care tests cover stale conflicts, galleries, reused media IDs, scroll,
archive navigation, forms and uncertain-write handling. An additional widget
test fails an API request outside the refresh loop and verifies automatic
fallback recovery and SSE return without manual reload. A real server test
checks that periodic keepalive is observable without changing a data cursor.

## Local HTTPS and Caddy evidence

[Sanitized transport evidence](data/shared-care-recovery-transport-2026-10-18.json)
uses the production API/stream handler and compiled production Dart web adapter.
The retained smoke runner additionally checks observable periodic keepalive with
`heartbeat=true`. Its disposable loopback fixture uses fresh SQLite databases;
it never opens the operator's collection. Caddy is version 2.11.4.

The transport run repeats 12 HTTP/1.1 and 12 HTTP/2 idle disconnect cycles, plus
eight real-command/hint/disconnect cycles in each of Chrome and Edge. It also
waits for a periodic keepalive in each browser without a collection write,
checks fragmented UTF-8/multiline delivery and verifies one unauthorized attempt
without native retry. Stream slots must return to zero after every close.

TLS uses an explicit disposable test certificate: Node verifies its supplied CA;
the launched Chromium processes pin that certificate's public-key hash. There
is no global TLS-error bypass or certificate-store import. This is a local
verified/pinned HTTPS transport check, not a Pi or end-user OS trust-install test.
Caddy keeps its standard event-stream flushing and upstream cancellation; see
the [official streaming documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#streaming).

To repeat the gateway check, use the compilation/runtime steps in the
[#228 procedure](shared-care-sse-delivery-validation-2026-10-18.md#reproduce-the-transport-smoke)
and add `heartbeat=true` to the Node runner. Build the fixture from this source
and use a fresh report path. The runner accepts explicit local certificate,
private-key and CA paths. Binaries and the disposable private key are excluded
from the source ZIP.

## Remaining device acceptance (#230)

This delivers #229's recovery policy and deterministic scheduling coverage.
Physical-browser lifecycle/OS trust, actual Flutter frame/paint behavior,
1/3/5/10-client Pi latency/traffic/CPU/RSS budgets and the 30-minute/100-reconnect
soak remain #230. Logical tabs in controlled-clock tests are not independent
physical devices. The gateway smoke isolates transport and does not measure
Flutter painting. The full standalone repository suite, Android and ARM64 build
are outside this local Shared Care validation.

Rebuild both the server and Shared Care web frontend when applying the ZIP so
the observable upkeep and client liveness policy are deployed together.
