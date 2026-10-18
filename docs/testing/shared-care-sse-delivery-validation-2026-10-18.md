# Shared Care SSE delivery — Issue #228

Date: 2026-10-18. Baseline: `0bd33b4b465ad8eaed1cfe962a70611d9162a1cb`.

## Delivered scope

- Production `GET /api/v1/changes/events`, authenticated by the existing cookie,
  with the existing origin/fetch-site policy and audience-filtered #226 hints.
- Commit/reset notifications and private preference/session signals; open-session
  revalidation, explicit expiry deadline and terminal authentication event.
- Bounded connection admission, retained replay, frame size and coalescing writer;
  idle disconnect detection, write deadlines and cancellation through Caddy.
- A separate injectable native browser EventSource port, including explicit close
  on transport errors and separation of received IDs from #227's applied cursor.
- Home integration: targeted authoritative reconciliation on hints, no idle
  conditional query while streaming is open/synchronized, existing conditional
  safety net when unsupported/failed or a required read failed. Logout,
  background/backup pause, foreground re-entry and disposal retain their hooks.
- Reproducible production-handler/browser transport fixture and sanitized evidence
  for the integrated #230 validation. No application dependency, device permission,
  collection schema or portable-backup-format change.

The [contract](../shared-care-change-contract.md#sse-delivery-issue-228) records
wire fields, limits and the remaining #229 policy boundary. This delivers #228's
transport; jitter/backoff, automatic recovery policy and the comprehensive
lifecycle/replay matrix remain #229. Real Flutter/Pi performance remains #230.

## Automated application checks

Flutter 3.47.2 / Dart 3.13.2 on Windows x64, using the existing dependency lock.
The dependency graph was resolved from the local cache. The host's pre-existing
Windows plugin symlink prerequisite prevents the final `pub get` step; checks
therefore use the resolved graph with `--no-pub`. No Windows setting was changed.

```sh
flutter analyze --no-pub
flutter test --no-pub test/shared_client test/shared_server \
  test/architecture/shared_care_boundaries_test.dart --reporter expanded
flutter test --no-pub test/shared_client/shared_change_stream_test.dart \
  --reporter expanded
flutter build web --no-pub --target lib/main_shared.dart
```

The broad Shared Care/architecture regression passed 264 tests. After the small
connecting-signal cancellation guard, the complete six-test SSE client file was
rerun. The guard prevents a state observer's immediate cancellation from creating
a late browser source. Final gates all passed:

| Gate | Result |
| --- | --- |
| Full `flutter analyze --no-pub` | No issues found |
| Shared Care client/server and architecture regression | 264 passed |
| Final SSE client file after connecting cancellation guard | 6 passed |
| Actual `lib/main_shared.dart` release web build | Passed, including Wasm dry run |
| Native `bin/shared_server.dart` CLI bundle | Passed, including SQLite native asset |
| Final compiled production fixture/adapter through HTTPS/Caddy | All 40 connection cycles passed |

The full standalone repository suite and Android build are
outside this transport validation.

New server tests cover cookie/origin/fetch-site rejection, secret-free frames,
real committed API commands versus failed writes, retained replay and reset
reasons, private preferences/admin filtering, idle expiry, revocation,
deactivation, eight/account and 32/global limits, 24 successive idle disconnects,
large-replay collapse, and export plus successful/failed restore while subscribed.
Writer tests send 10,000 wakeups during one stalled write, test the single pending
write, timeout termination and cancellation of pending deadlines on disconnect.
Client tests cover one source, stale callbacks, malformed/oversized events,
received/applied cursor separation during failed reads, unsupported transports,
authentication termination, cancellation during connection, targeted widget
updates, idle-query suppression, conditional safety net and pause/resume hooks.

## Actual browser and gateway test

The repeatable runner uses the production API/stream handler and the compiled
production Dart web adapter; it does not substitute the #186 laboratory feed.
The fixture binds only to loopback and creates disposable SQLite databases and a
known test-only account. It exposes fixture diagnostics only in that test process.
It never opens a production collection or writes credentials into its report.

Caddy 2.11.4 Windows amd64 was downloaded from its official release and matched
against its official SHA-512 checksum. The runner preserves `deploy/Caddyfile`'s
API reverse-proxy directives, replacing only local addresses/certificate/root
paths and adding the fixture-only test route. No buffering/low-latency override
was added. Caddy automatically flushes `text/event-stream`; explicitly setting
`flush_interval -1` would prevent early client cancellation of the upstream.
See the [official Caddy streaming documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#streaming).

TLS verification was explicit: a seven-day disposable test certificate with
loopback SANs was trusted by Node using its supplied CA; Chrome/Edge were pinned
to that certificate's public-key hash for this test process. There was no global
certificate-error bypass and no certificate-store import. This proves the local
verified/pinned HTTPS transport, not an end-user OS trust installation on the Pi.
The private key and local runtime artifacts are excluded from the delivery.

Evidence: [sanitized transport results](data/shared-care-sse-delivery-2026-10-18.json).

| Path | Workload | Result |
| --- | --- | --- |
| Caddy HTTPS HTTP/1.1 | 12 open/initial-frame/idle-disconnect cycles | 0 retained streams after every cycle |
| Caddy HTTPS HTTP/2 | 12 equivalent cycles | 0 retained streams after every cycle |
| Chrome 155.0.8059.84, HTTP/2 | 8 open/real command/hint/disconnect cycles | Valid authorized hints; 0 retained streams |
| Edge 155.0.4283.62, HTTP/2 | 8 equivalent cycles | Valid authorized hints; 0 retained streams |
| Both browsers, actual Dart adapter | Single-byte chunks splitting CRLF, fields, JSON and multibyte UTF-8; multiline data | One correct event with its transport ID and original Unicode |
| Both browsers | Initial unauthorized stream, observed for 3.5 seconds | One request; source closed; no native retry loop |

No Pi latency, RSS/CPU budget, 30-minute soak, physical mobile/Safari/Firefox or
HTTP/3 acceptance is inferred from this local smoke. Those remain in #230's
physical-browser/device matrix. Full Flutter widget behavior is verified by the
application tests; this browser fixture isolates the actual EventSource adapter.

### Reproduce the transport smoke

Use an isolated checkout, the locked Dart toolchain, Node with Playwright and
installed Chrome/Edge, Caddy 2.11.4, and a local loopback TLS certificate/key/CA.
Use a temporary output directory outside tracked repository paths. For native
SQLite assets use `dart build cli`, not a bare `dart compile exe`.

```sh
dart compile js tool/validation/shared_care_sse_browser.dart -O2 \
  -o /tmp/tm228/adapter.js
dart build cli --target=tool/validation/shared_care_sse_fixture.dart \
  --output=/tmp/tm228/fixture
node tool/validation/shared_care_sse_smoke.cjs \
  fixture=/tmp/tm228/fixture/bundle/bin/shared_care_sse_fixture \
  adapter=/tmp/tm228/adapter.js caddy=/path/to/caddy \
  cert=/path/to/test.crt key=/path/to/test.key ca=/path/to/test-ca.crt \
  output=/tmp/tm228/transport-results.json
```

On Windows the fixture executable ends in `.exe`. The TLS certificate must cover
`127.0.0.1`. With a CA already trusted by the test browsers no additional browser
argument is needed. For a disposable certificate, optional `spki=<base64 SHA-256
of DER SubjectPublicKeyInfo>` pins just that certificate for the launched Chromium
processes. The runner always verifies Node HTTPS using `ca`, rejects reused report
paths, closes its child processes and checks that its temporary cleanup path stays
inside the selected system temporary directory.

### Next acceptance stages

- #229: bounded jitter/backoff; automatic SSE recovery from fallback; deterministic
  setup/replay/outage/session/lifecycle/restore cases across multiple tabs.
- #230: real Flutter UI, trusted target-device HTTPS and physical browsers at
  1/3/5/10 clients; repeated idle/write workloads, latency/traffic/CPU/RSS budgets
  and a 30-minute/100-reconnect run.

Rebuild both server and Shared Care web artifacts when applying the source ZIP.
The production gateway configuration already supports SSE; its added comments
retain the cancellation/flushing requirements for subsequent deployment edits.
