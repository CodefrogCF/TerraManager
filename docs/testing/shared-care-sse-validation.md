# Focused polling/SSE validation after the architectural decision

## Scope and status

Prepared on 2026-10-18 following the operator's SSE decision. This procedure is
not an executed result. It compares the existing polling baseline with the
selected laboratory SSE candidate: five logical Chrome clients, overview,
120 seconds per window, idle/writes, three repetitions. Twelve windows give
24 minutes of measured time plus browser setup/cleanup, normally about 25-30
minutes in total. The mode/workload order alternates between repetitions;
it is not randomized. All trials use the same warm lab, keeping audit/session
history while deleting only the Feedings created by each runner.

The existing version-polling pilot remains fallback evidence. These repeats
do not implement production SSE, replace the real Flutter baseline, validate
the known extra gallery lookup, or complete the wider client/browser matrix.

## Disconnect correction and the first repeated run

The first repeated run stopped after nine completed windows when the laboratory
held 32 stream slots after the clients had disconnected. That resource comparison
must be repeated with a fresh lab. See the
[failure/correction record](shared-care-sse-disconnect-correction-2026-10-18.md).

After applying the correction on the Pi, use this once to stop the matching old
sampler, rebuild/recreate only the disposable lab, export its new private test
credentials, and start a fresh resource capture:

~~~sh
TM186_HOST=192.168.1.117 TM186_INTERFACE=wlan0 \
TM186_PREVIOUS_RUN="$HOME/tm186-private/sse-20261017T221930Z" \
  bash tool/evaluation/shared_updates/restart_sse_validation.sh
~~~

Recreating the lab resets its synthetic data and changes the generated test
password. Transfer ~/tm186-private/credentials.json to the controller's private
credentials file before starting the next browser run. Do not publish it.
The previous host-side resource directory is retained.

## Pi: switch only the separate gateway and start resources

Apply this ZIP to the Pi checkout first. The following block switches the 8443
gateway back from Flutter assets to the lab page. It keeps the current lab
container and its generated credentials. The production project on 443 is
separate. The collector first performs a 12-second probe; it starts the longer
capture only if both process RSS/CPU probes succeeded.

~~~sh
TM186_HOST=192.168.1.117 TM186_INTERFACE=wlan0 \
  bash tool/evaluation/shared_updates/start_sse_validation.sh
~~~

Keep the run directory private. Share its printed path and preflight RSS lines
with the controller operator; do not share credentials. If preflight fails, keep
the error output and preflight.jsonl. The long capture is not started in that case.
The 45-minute capture provides setup headroom; the trial windows come from the
controller manifest, not the whole collector file. If controller setup is delayed
beyond that headroom, start a new capture before running the comparison.

## Controller: inspect the plan, then run

Use the existing private Node/Playwright/Chrome setup with trusted TLS. No browser
or Node certificate-validation bypass is required or accepted.

~~~sh
node tool/evaluation/shared_updates/run_sse_comparison.cjs --plan

node tool/evaluation/shared_updates/run_sse_comparison.cjs \
  --credentials /private/credentials.json \
  --output-dir /private/NEW-sse-comparison \
  --clients 5 --seconds 120 --repetitions 3 --head SOURCE_COMMIT
~~~

The output directory must not exist. Individual trial files and manifest.json
are saved after each completed trial. The controller checks for zero active lab
streams before the first window and after every completed child, waiting at most
five seconds for cleanup. It stops on failed/missing observations, failed cleanup
or residual streams. Do not concatenate a later attempt into the same
run. The runner never forwards Playwright request logs, which can contain secrets.

## Interpretation and remaining gates

- Align resource data with each result's startedAt/finishedAt UTC, using each
  process probe's own observed_utc timestamp for process attribution.
- CPU seconds = delta(user ticks + system ticks) / clock_ticks_per_second.
  Use the actual first/last probe span within each trial. Discard pairs across
  changed start_time_ticks, negative deltas or missing probes; report coverage.
- Sampled RSS describes the main Dart/Caddy process, not total container memory,
  tmpfs or an exact instantaneous peak. VmHWM spans the process lifetime.
- Docker CPU samples and cumulative process CPU have different scopes; keep both.
  Read-only docker exec probes add measurement overhead consistently in all modes.
- Keep individual repetitions separate; report distributions across repetitions
  rather than treating every client's observation as an independent trial.
- Record idle fetches, body/upkeep counters and WLAN traffic with their separate
  scopes. Host WLAN includes SSH/other traffic. Do not add proxy/backend NetIO.
- Target five-client connected behavior: p95 lab update <= 2 seconds, at least
  90% fewer idle data fetches and 80% fewer received bytes including upkeep.
  A lab pass does not prove real Flutter performance or production recovery.
- Remaining work: scale/browser/lifecycle scenarios, the post-header abort
  diagnostic, production committed invalidations, authenticated streaming,
  targeted Flutter refresh, fallback and reconnect/restore correctness.

Process counter semantics: [Linux proc_pid_stat](https://man7.org/linux/man-pages/man5/proc_pid_stat.5.html).
See [ADR-037](../architecture-decisions.md#adr-037-evaluate-versioned-shared-care-invalidation-and-sse-delivery)
and the [main runbook](shared-care-update-evaluation.md).
