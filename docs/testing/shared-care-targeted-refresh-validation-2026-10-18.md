# Shared Care targeted refresh validation — Issue #227

## Baseline and scope

Based on `7935f7a34aaa13a3dd7865108906347f93eb1795`, including the adopted
#226 committed-change API. Implementation and validation use an isolated source
copy; the primary checkout is preserved. No dependencies or permissions change.

## Controller and dependencies

`SharedApiClient.refresh` owns one transient controller per browser tab/session.
It stores invalidation flags and opaque applied/dispatched cursors in memory.
Actual records remain in the existing mounted UI state. Signing out/signing in
resets cursor ownership; old in-flight reconciliation cannot acknowledge a cursor
for a new session. Closing the API disposes subscriptions and clock deadlines.

| Consumer | Dependencies | Refresh behavior |
| --- | --- | --- |
| Animal overview/archive | Animals, Boxes, reminders | Shared list snapshots; image cache retained by immutable media ID |
| Box overview/archive | Boxes, assigned Animals | Shared list snapshots, including former/new assignment hints |
| Animal detail | selected Animal, Box labels, its Feeding/Weight/Shedding histories, reminders, navigation list when present | Read only affected parts; retain gallery subtree and scroll |
| Box detail | selected Box, assigned Animals, navigation list when present | Read affected parts and retain gallery subtree |
| Owner gallery | `animalPictures`/`boxPictures` owner ID | Replace metadata after a successful read; Feeding-only hints do not match |
| History route | corresponding history kind and Animal owner | Update current list; an open editor dialog retains its draft |
| Account settings | audience-scoped `preferencesChanged` or reset | Serialize with local preference writes, GET stored preferences, retain session identity |
| Due state | existing reminder/history deadlines and current time | Rebuild at the due deadline; no collection GET or database write |

Editing forms, Feeding Mode selection/notes, scanner/camera state and audit
filters remain owned by their existing routes. They are not overwritten with
background snapshots. The server retains existing permission/conflict checks.
Account/audit management is not redefined as a collection mutation.

## Cursor and race handling

1. Initial screens retain their existing initial loads. The first conditional
   query establishes a reset baseline and reloads its required visible resources.
2. A query is made from the last application-applied cursor. New advertised
   cursors dispatch normalized, coalesced invalidations to matching consumers.
3. Required visible reads run serially. Hints for hidden consumers remain dirty.
   Another hint arriving during a read is retained for a subsequent pass.
4. The query cursor is applied only after required reads succeed. Failed reads
   retain their dirty hints and the previous applied cursor for retry.
5. A post-read query catches commits made during loading. A 304 with no dirty
   consumers causes no collection GET, future replacement or list replacement.
6. Local command acknowledgements reconcile the same change API; another device
   using the same account is not filtered out. A gallery/history already refreshed
   by the acknowledgement reuses that result.

Resource ID sets are bounded to 128 IDs per kind, then become a conservative
whole-kind hint. A reset collapses to one broad stale marker. No persistent
collection or cursor cache is introduced. Media IDs are immutable within a
collection epoch. Reset/session boundaries advance a tab-local media generation:
network image URLs use that non-secret number as a cache key, and overview byte
caches clear when their generation changes. This also handles restored pictures
reusing old IDs; ordinary Feeding updates retain the generation and caches. Individual HTTP reads remain separate
snapshots; this does not promise an atomic multi-request database snapshot.

## CI architecture repair from #226

`CareChangeHints.capture` previously imported `dart:io` and accepted `HttpRequest`
inside `shared_server/changes/application`. This violated the existing server
application-layer architecture test. The HTTP handler now extracts path segments
and method and passes these values to hint capture. Commit timing, old/new Box
IDs, idempotency and transaction semantics remain covered by server tests.
The architecture gate is retained without exceptions.

The added archive widget regression also exposed a sibling-route notification
during `didUpdateWidget`. Animal/Box overview snapshots are now published to an
open archive after the current frame, guarded against disposed/replaced notifiers.
Both archive kinds are covered, including their remote rename while home is hidden.

## Validation

Toolchain: Flutter 3.47.2 / Dart 3.13.2 on Windows. The following combined
regression command passed **181 tests**:

```sh
flutter test --no-pub test/shared_client test/architecture/shared_care_boundaries_test.dart test/shared_server/committed_changes_test.dart test/shared_server/shared_changes_test.dart --reporter expanded
```

This includes the full VM Shared Care client suite, all three architecture tests,
and the committed-change/conditional API server regressions. The new coverage
includes dependency matching and both Box assignments, bounded/empty hints,
unchanged revisions, bursts, overlapping/failed reads, initial-load races,
session reset, due deadlines without queries, retained scroll/gallery/form state,
remote updates in both archive routes, and image IDs reused after reset.

| Gate | Command | Result |
| --- | --- | --- |
| Whole-project analysis | `flutter analyze --no-pub` | No issues found |
| Web build including Wasm dry run | `flutter build web --no-pub` | Passed |
| Source consistency | SHA-256 of all 546 tracked/new Dart source files before/after final gates | Identical |

The final gate used frozen source contents. Delivery verification checks these
source hashes again, as well as ZIP contents/integrity and the unchanged primary
checkout before creating the archive.

The dependency graph was resolved from the existing offline Pub cache. Flutter's
plugin setup reported the Windows symlink/developer-mode prerequisite; validation
used the resolved locked graph with `--no-pub`. `pubspec.lock` remains identical
to the baseline. No global Windows or Flutter setting was changed.

## Integration boundary

The existing 15-second interval now triggers one central conditional change query
instead of unconditional collection GETs from home plus independent detail timers.
The first reset/manual reload may intentionally read several resources; steady
unchanged state does not. Existing background and exclusive-backup pauses remain,
and foregrounding reconciles the clock and committed changes.

- #228 adds the authenticated SSE endpoint and EventSource adapter. It can call
  `invalidate`/`reconcile`; an event's advertised ID never directly applies data.
- #229 owns reconnect backoff, transport state, foreground recovery and fallback
  switching. Those broader policies are not implemented by this change.
- #230 retains real Flutter/browser/Pi integrated performance and memory acceptance.
  No fresh device latency, CPU, RSS or bandwidth result is claimed for #227.

No full repository test suite, Android build, Pi ARM64 runtime build, or physical
browser/device acceptance is implied by the client/server regression gate.
