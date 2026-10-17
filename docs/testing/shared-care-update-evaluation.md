# Shared Care update evaluation (Issue #186)

## Status and scope

This is a repeatable evaluation kit, not a production synchronization change.
The production entry point, authentication, role checks, conflict detection,
backup gate, database schema and Flutter pages are unchanged. The new server
entry point always creates a fresh private scratch database and generated test
account. It accepts no production database path and does not use TM_DATABASE_PATH.

The local and target-device reports record executed checks separately. The ARM64
Pi/Caddy/Chrome HTTP/2 pilot includes browser results and CPU/network samples.
The real Flutter client was also exercised through the separate gateway; see the
target-device report for the observed workload and measurement boundaries.
Per-trial RAM accounting, repeated trials, the wider browser/lifecycle matrix
and implementation acceptance remain pending. The operator selected the SSE
architecture direction on 2026-10-18; ADR-037 records that decision separately.

## Workloads and measurements

The normal overview has a 15-second timer and requests Boxes, Animals and
reminders: a nominal 12 GET requests/minute/client. Animal details additionally
request six resources when navigation context is present; the overview remains
mounted. This gives a nominal 36 GETs/minute in that model. The real Flutter
baseline measured 40: it also included one picture-list lookup per refresh,
even with no pictures. The target-device report records that result
and its diagnostic limits; the overview-only transport comparison is unaffected.

The browser runner models those API paths and ordering with isolated browser
contexts and the REAL SharedServerApi/SQLite operations on synthetic data.
The detail-stack workload models a detail with navigation context. It is not
the Flutter application and cannot measure Flutter frame timings or prove
actual route/background behavior.

Modes share the same fixture and initial snapshot:
- polling: full overview/detail reads every configured interval;
- version-polling: one small change query with If-None-Match; unchanged state
  returns HTTP 304 for a matching ETag, otherwise HTTP 200 JSON;
- long-polling: the same query waits up to 25 seconds;
- sse: browser EventSource with replay IDs and 15-second comment heartbeats;
- websocket: a browser WebSocket with the same bounded change hints.

Only successful POST /api/v1/feedings requests publish a lab notification.
The wrapper observes completion after the production API has committed and
sent its response. It is NOT a reusable production commit hook. Invalid writes
do not publish. Idempotent replays can conservatively produce another hint;
production deduplication is a follow-up requirement. Other mutation kinds are
not connected to the laboratory feed.

Notifications contain domains and revisions, never full records or audit data.
A 128-entry buffer resets clients with old/future/foreign cursors. The feed is
process-local. The lab caps long-lived requests at 32. Session validity is
checked on changes and 15-second heartbeats. SSE coalesces writes and bounds
flush waits. These are prototypes; slow-consumer hardening, retry jitter,
revocation deadlines, fallback and restore integration are production follow-ups.

## Local run (Windows or Linux)

Use Flutter 3.47.2 and its bundled Dart 3.13.2 for the repository package graph.
Resolve dependencies and run from the repository root:

~~~text
flutter pub get
dart run tool/evaluation/shared_updates/lab_server.dart --serve
~~~

The server prints a JSON line with listenerPort and credentialsFile. It prints
no password. The generated credentials file is private test input, not evidence
to attach to GitHub. The default origin uses localhost and a random loopback
port. Stop with Ctrl+C; normal shutdown deletes the scratch databases and test
credentials. A crash can leave that private scratch directory; remove that
specific directory after the process has stopped.

LAN binding is refused without an explicit HTTPS public origin. Use Caddy and a
trusted certificate for remote clients. Do not bypass certificate verification.

### Windows controller certificate preparation

The Node process making Playwright API requests and the automated browser must
both trust the LAN certificate authority. A successful visit in a separately
configured browser does not establish trust in a new automated Chrome profile.
Check the public LAN CA certificate and its fingerprint against the certificate
used for the Shared Care deployment. Use only the public CA certificate here.

For Node, supply the public CA in PEM format to this PowerShell session before
starting the runner:

~~~powershell
$env:NODE_EXTRA_CA_CERTS = 'C:\PRIVATE\TerraManager-LAN-CA.pem'
~~~

This adds a CA for the Node process; it does not configure browser trust. On a
Windows Chrome controller, the operator can explicitly approve importing the
same public CA into the current user's trusted root certificate store:

~~~powershell
Import-Certificate -FilePath 'C:\PRIVATE\TerraManager-LAN-CA.pem' `
  -CertStoreLocation 'Cert:\CurrentUser\Root'
~~~

That trust-store change also affects other programs for this Windows user and
requires the operator's approval. The runner never imports certificates itself.
Before a timed trial, verify that both the Node HTTPS health request and a fresh
automated browser can reach the test origin with certificate validation active.
Record the public CA fingerprint, trust source and browser protocol with the
test evidence.

Reference: [Node additional CA certificates](https://nodejs.org/api/cli.html#node_extra_ca_certsfile).

### Browser controller tools

The browser runner uses Playwright 1.62.1 as an OPTIONAL external test tool.
Install it in a private tooling directory outside the project, then expose that
directory's node_modules through NODE_PATH. Example on Linux:

~~~sh
mkdir -p /tmp/tm186-browser-tools
npm install --prefix /tmp/tm186-browser-tools --ignore-scripts playwright@1.62.1
export NODE_PATH=/tmp/tm186-browser-tools/node_modules
~~~

The default Chromium run uses the installed Chrome channel. Firefox and WebKit
require their corresponding Playwright browser installations; install these
explicitly if they belong to the agreed browser matrix. No package or browser
is downloaded automatically by the benchmark runner.

~~~sh
node tool/evaluation/shared_updates/browser_benchmark.cjs \
  --credentials /PRIVATE/PATH/credentials.json \
  --output /PRIVATE/PATH/overview-5-clients.json \
  --clients 5 --seconds 120 --mode all --view overview \
  --poll-ms 15000 --change-ms 20000 --head GIT_COMMIT
~~~

Use a NEW output path per run. The runner refuses to overwrite a report.
Use --change-ms 0 for the idle workload (no writes).
Use --view detail-stack for the modeled detail workload. Use --browser firefox
or --browser webkit for other installed engines.

There is a mutation settle window of pollMs + 1500 ms before the end, so polling
clients can observe the last write. Use long runs (at least 120 seconds, preferably
10 minutes per mode) for performance comparisons. The runner removes only the
Feeding IDs that it created, through the authenticated API, between modes.
Restart the disposable server for a completely fresh repeated trial.
For acceptance measurements, run one --mode per fresh lab and repeat/randomize
the order. The convenient --mode all smoke sequence retains audit/session
history between modes even though its generated Feedings are removed.

## What the browser report means

Warm-up/login/initial snapshot are excluded. The report includes:
- actual request starts and HTTP statuses from the workload;
- UTF-8 bytes of completed fetch response bodies;
- Chromium CDP encoded/decoded received body counters, including ongoing streams;
- received WebSocket payload bytes (separate, not added to encoded HTTP bytes);
- lab DOM updates and errors;
- expected and observed write markers;
- write-start-to-lab-DOM p50/p95 latency in the controller clock.
- per-mode UTC start/end timestamps for aligning separate resource samples.

That latency includes the write request, server work, notification/poll wait,
data refresh and lab rendering. It is not a direct database-commit timestamp.
All logical clients share the controller clock; no cross-device clock claim is
made. The marker is a new Feeding time visible in latestFeedingAt/history.
Writes are normally spaced more than one poll interval apart; faster write
cadences can hide intermediate latest-feeding markers in an overview and must
not be reported as database data loss.

CDP body/payload counters exclude HTTP headers, TLS/TCP overhead and outgoing
traffic. Completed fetch bytes alone would omit SSE heartbeats; do not use that
field to claim total SSE bandwidth. CDP capture on non-Chromium engines is null.
One host's browser contexts do not establish a physical multi-device result.

## Real Flutter baseline

Export a private HAR of the actual Shared Care Flutter browser after login and
warm-up, then capture a known observation window. Use overview/detail and idle/
scripted changes separately. The HAR can contain secrets: keep it local and
export without response contents where possible.

~~~sh
python tool/evaluation/shared_updates/summarize_har.py PRIVATE.har \
  --window-seconds 600 --output sanitized-api-summary.json
~~~

The summarizer emits normalized routes, request/status counts, known HAR body
sizes and request durations. It omits hosts, IDs, query values, cookies, headers
and bodies. Unknown sizes remain unknown. Request duration is not cross-client
update latency. Record the intentional capture window separately; the automatic
span runs from first request to last response and is not used to invent a rate.
Use the actual known duration with --window-seconds (600 above assumes an exactly
ten-minute recording). Without it, request rates remain null. Capture Flutter build/frame
timings separately in DevTools; the lab DOM counter is not a Flutter rebuild
counter. Health checks and login should be reported separately from data polling.

## Isolated Raspberry Pi / Caddy stack

Use the kit from an isolated source copy on the Pi. The compose project is named
tm186-evaluation and requires a 64-bit Linux/ARM64 Docker host. It
publishes port 8443 only, mounts no collection/account storage
and uses private tmpfs scratch data. Keep the production stack running unchanged.
The certificate mount is read-only and must contain server.crt and server.key
trusted by the test browsers. Caddy uses these files directly, without ACME or
another cloud service.
The Dockerfile-specific ignore file allowlists only required source and server
dependency files; credentials, HAR/results, Git history and native signing files
are excluded from this evaluation build context.

Set all variables explicitly. Example (replace addresses and certificate path):

~~~sh
export TM186_HOST=192.168.1.50
export TM186_BIND_IP=192.168.1.50
export TM186_PUBLIC_ORIGIN=https://192.168.1.50:8443
export TM186_CERT_DIR=/PRIVATE/ABSOLUTE/PATH/certs
export TM186_ANIMALS=100
export TM186_HISTORY=20
docker compose -f tool/evaluation/shared_updates/compose.yaml config
docker compose -f tool/evaluation/shared_updates/compose.yaml up -d --build
docker compose -f tool/evaluation/shared_updates/compose.yaml logs lab
~~~

The log reports the private credentials file path inside the lab container.
The container mounts /tmp as tmpfs. Do not use docker cp or docker compose cp
to export this file: Docker documents copying limitations for tmpfs mounts.
Read it through docker exec in the running container instead. The following
block can run from any directory on the Pi. It discovers the current random
scratch path, requires exactly one credentials file, and only replaces the
private host copy after a successful non-empty export. It prints no credentials.

~~~sh
(
  set -eu
  umask 077
  install -d -m 700 "$HOME/tm186-private"
  tm186_credentials_tmp="$(mktemp "$HOME/tm186-private/.credentials.XXXXXX")"
  trap 'rm -f -- "$tm186_credentials_tmp"' EXIT

  docker exec tm186-evaluation-lab-1 sh -eu -c '
    set -- /tmp/tm186-*/credentials.json
    if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
      echo "Expected exactly one active lab credentials file." >&2
      exit 1
    fi
    cat -- "$1"
  ' > "$tm186_credentials_tmp"

  test -s "$tm186_credentials_tmp"
  chmod 600 "$tm186_credentials_tmp"
  mv -f -- "$tm186_credentials_tmp" "$HOME/tm186-private/credentials.json"
  printf '%s\n' 'OK: ~/tm186-private/credentials.json'
)
~~~

If the block fails, keep the error output and inspect the current lab logs;
do not transfer an older credentials file. No container restart is needed for
this export. Copy ~/tm186-private/credentials.json from the Pi to the private
browser-controller directory over your existing SSH/SCP connection. Do not
paste its contents into chat/issues or commit it. The credentials origin
already points to the separate HTTPS gateway.

Reference: [Docker cp corner cases](https://docs.docker.com/reference/cli/docker/container/cp/#corner-cases).

Run browsers on a laptop/controller so their CPU does not pollute Pi server
measurements. Run the resource collector ON THE PI in parallel, using the
container names returned by docker compose ps:

~~~sh
python tool/evaluation/shared_updates/sample_resources.py \
  --container tm186-evaluation-lab-1 \
  --container tm186-evaluation-gateway-1 \
  --interface eth0 --seconds 700 --interval 2 \
  --output pi-resources.jsonl
~~~

The collector records hardware metadata where available, Docker CPU/RAM/NetIO/
BlockIO and optional host interface byte counters. CPU/RAM samples must be
aligned with each report's time window. Docker CPU percentages can exceed 100%
across cores. Synchronize Pi/controller clocks before aligning UTC samples.
The configured sleep interval comes after Docker stats collection; inspect the
recorded timestamps for the actual cadence. These are intermittent CPU samples,
so brief bursts can be missed. Do not use their mean as an integrated CPU-time
measurement or derive a precise CPU reduction from one pass.
Treat Docker memory output of 0B / 0B as unavailable. Read-only process VmRSS and
VmHWM values can supplement it, but process RSS excludes separate tmpfs/page-cache
accounting and the lifetime high-water mark cannot be assigned to one trial.
The collector's optional --process-stats mode now records PID 1 RSS/high-water
and user/system CPU ticks through read-only docker exec probes, with separate
timestamps and the process start-time identity. CPU deltas divided by the host's
clock_ticks_per_second measure consumed process CPU time over the observed span;
discard deltas across changed identities or counter resets. These are process
metrics, not a reconstruction of total container memory. See the
[focused validation procedure](shared-care-sse-validation.md).
Sampling uses fixed deadlines and records skipped slots after overruns rather
than adding the collection duration to every requested interval.
NetIO is per container: summing gateway and backend double-counts
internal traffic. Host interface counters include unrelated traffic (for example
SSH); isolate or account for it. The evaluation image retains Dart/coreutils for
the laboratory, unlike the minimal production image; compare process/container
steady-state metrics, not image disk sizes.

Run 1, 3, 5 and 10 clients, overview/detail-stack, idle and updates, with at least
three repetitions and the same fixture/browser/version/poll interval. Also record
server cold/warm state, gateway protocol, network conditions and Pi throttling.
Physical Chrome/Edge/Firefox/Android browser and applicable Safari tests remain
a separate matrix, including several tabs, background/foreground and reconnects.
Start with a representative five-client comparison across all transports, then
repeat the baseline and shortlisted candidates across the wider client matrix.
Avoid spending the full matrix on an option already rejected for a documented
compatibility or correctness reason.

Stop only this disposable project after the run:

~~~sh
docker compose -f tool/evaluation/shared_updates/compose.yaml down
~~~

### Measure the actual Flutter client against disposable data

After the transport runs, the optional compose.flutter.yaml override reuses an
existing TerraManager Shared Care Web image (with its /srv/web assets) for the
separate gateway. It proxies API requests to the same disposable lab database.
It does not mount or contact the production collection. Record the exact Web
image tag/ID and application version; do not assume it matches the server commit.

~~~sh
export TM186_WEB_IMAGE=terramanager-web:YOUR_EXISTING_TAG
docker compose -f tool/evaluation/shared_updates/compose.yaml \
  -f tool/evaluation/shared_updates/compose.flutter.yaml config
docker compose -f tool/evaluation/shared_updates/compose.yaml \
  -f tool/evaluation/shared_updates/compose.flutter.yaml up -d --no-deps gateway
~~~

Open the HTTPS test origin on port 8443 and log in with the private generated
test credentials in a separate browser profile or private window. Cookies for
the same host are shared across ports, so a separate profile keeps the test
login separate from the production login on port 443. The automated runner
already creates isolated browser contexts. See [RFC 6265 section 8.5](https://www.rfc-editor.org/rfc/rfc6265.html#section-8.5).
This now runs the real Flutter UI against synthetic data:
capture HAR/frame measurements and cross-client behavior here. The browser
transport runner expects the lab root page, so use these as separate phases.

For a repeatable automated network baseline, run the following on the browser
controller with the same optional Playwright/Chrome and trusted-CA preparation:

~~~sh
node tool/evaluation/shared_updates/flutter_baseline.cjs \
  --credentials /private/credentials.json \
  --output /private/flutter-baseline.json \
  --clients 5 --seconds 120 --observe-change
~~~

This helper signs in with separate browser contexts, activates Flutter semantics,
and measures the Animal overview and Animal detail for the specified duration
each. It verifies that the backend identifies itself as the disposable lab and
refuses the laboratory HTML root page. The default fixture must be present.
The optional --observe-change flag creates one synthetic Feeding for Animal 1,
observes its changed Last Feeding semantics, and deletes the created record.
Omit that flag for a read-only baseline. Generated sessions/audit entries remain
in the temporary lab. Production credentials or data must not be used.

Reports contain route/status counts, normalized numeric IDs, browser Resource
Timing body/transfer sizes, visibility/focus snapshots, page errors and main-frame
navigation counts. They contain no credentials, headers, cookies or record bodies.
Retain the failureEvents detail: post-header ERR_ABORTED events occurred in the
control run despite HTTP-200 responses and a working UI. They are not silently
discarded or automatically equated with application-visible failures. Likewise,
framenavigated includes same-document Flutter routes; use mainDocumentRequests
and navigation timing entries to identify document reloads.
Resource Timing is not a complete LAN-byte measurement. Semantic update detection
is not a paint timestamp or Flutter frame/rebuild count. One write observed by
five clients is a small correlated sample, not a latency percentile distribution.
Collect Pi CPU/RAM independently during any run that needs resource attribution.

Return the test gateway to its default lab page when needed:

~~~sh
docker compose -f tool/evaluation/shared_updates/compose.yaml up -d --no-deps gateway
~~~

The first completed run recorded 120 overview and 400 detail-stack HTTP-200
data GET responses across five clients in separate 120-second windows
(12 and 40 GETs/min/client). Browser cancellation events were retained and
examined in a separate short control; this is not a zero-network-error claim.
The [target-device report](shared-care-update-evaluation-pi-2026-10-17.md) records
the one-write semantics observation and all measurement limits.

The override has run on the target Pi with the existing Web image and trusted
Chrome HTTP/2. Record an immutable image ID/digest for repeatable build provenance.
Add synthetic media/large histories through
the normal test UI if those belong to a case; the default seed contains no media.

## Decision and completion gates

The [Raspberry Pi pilot report](shared-care-update-evaluation-pi-2026-10-17.md)
records the completed five-client transport comparison and its resource-data
limitations. Keep this target-device evidence separate from the earlier local
Windows laboratory results.

Selected direction (2026-10-18): committed revisions, central targeted invalidation,
SSE notifications and conditional/version polling fallback. See ADR-037 and the
follow-up issue drafts. The architectural choice does not mark outstanding
measurements or the production implementation complete.

Targets to validate (not achieved claims):
- at least 95% of updates visible within 2 seconds with five LAN clients;
- at least 90% fewer idle data requests and 80% fewer idle bytes including upkeep;
- no data-dependent list rebuild on unchanged versions or heartbeat;
- automatic convergence after reconnect, process restart and successful restore;
- CPU/RAM budgets defined after the Pi baseline and bounded queues/connections.

Issue #186 remains open until actual Pi/current-Flutter measurements, browser/
Caddy evidence and focused follow-up issue scope are recorded and the remaining
evaluation evidence is reviewed. The architecture decision is now recorded.
A local loopback prototype run alone does not satisfy those completion gates.

