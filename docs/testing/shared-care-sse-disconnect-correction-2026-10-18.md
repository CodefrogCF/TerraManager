# SSE laboratory disconnect correction, 2026-10-18

## Repeated run outcome

The comparison started at 2026-10-17T22:20:25Z (2026-10-18 local time). Nine
windows completed; the tenth failed during SSE startup. This was a failed,
partial run, not a completed three-repetition acceptance measurement.

All completed write windows delivered their expected observations. The runner
created and deleted 24 synthetic Feedings; 120/120 observations arrived. Counts
below aggregate five logical Chrome contexts per 120-second overview window.

| Repetition | Polling idle data GETs | SSE idle data GETs | Polling write p95 ms | SSE write p95 ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 120 | 0 | 12738 | 201 |
| 2 | 120 | 0 | 12752 | 163 |
| 3 | 120 | no measured window | not run | not run |

These lab DOM timings and fetch counts remain partial observations. Per-trial
resource comparisons cannot be accepted with accumulating orphaned streams.
Earlier exploratory resource measurements must also retain this caveat.

## Failure evidence

- The controller stopped after nine windows and retained the original files.
- The authenticated laboratory metrics endpoint reported streams=32 after the
  reader browsers had closed. The endpoint was still at 32 during a later probe.
- The laboratory's configured limit is 32, so subsequent SSE requests are rejected.
- A new raw-socket regression reproduced a retained slot after the first client
  disconnected from the original implementation.
- This laboratory lifetime defect is separate from the earlier Flutter
  post-header ERR_ABORTED diagnostic.

## Correction

The evaluation-only SSE endpoint now owns a dedicated close-delimited HTTP
connection. It observes the socket's input completion/error, destroys the socket
on disconnect and wakes the handler's finally block. That block cancels the
timer/subscription and releases the slot. It does not wait for a potentially
stalled response sink to finish before releasing application resources.

Response status/content type, event framing, replay cursors and authentication
checks are retained. A session-expired event is flushed before disconnect.
Production server entry points and collection handling are unchanged.

The comparison controller now checks for zero active streams before the first
window and after each child completes. Residual streams cause an immediate
failure after a bounded drain wait, with an allowlisted diagnostic category.
It does not forward request logs containing possible credentials.

## Verification

- Regression fails against the original endpoint: expected zero slots, observed one.
- Forty successive raw-socket disconnect cycles pass after the correction.
- The laboratory Flutter test file passes, including replay/authentication,
  WebSocket, long polling, complete session-expired framing and repeated disconnects.
- Focused Dart analysis reports no issues.
- The native CLI bundle builds with its SQLite asset through dart build cli.
- Forty actual Chrome EventSource cycles against the local native bundle leave zero streams.
- The new controller guard rejects the existing Pi lab with streams=32 before starting browsers.

Local native/Chrome checks use Windows loopback. The corrected ARM64 image and
Caddy HTTPS path still require the next target run; no such pass is claimed here.

## Restart and repeat

Apply the corrected files on the Pi and follow the
[restart procedure](shared-care-sse-validation.md#disconnect-correction-and-the-first-repeated-run).
It stops only the matching old sampler, rebuilds/recreates only the disposable
lab, preserves the old host-side resource directory, exports the newly generated
private credentials and starts a new capture. Transfer the new credentials to
the controller before running again. Use a new output directory and repeat the
whole comparison; do not merge this partial run into a successful run.

The SSE architectural choice remains recorded in ADR-037. Production lifecycle,
fallback and performance acceptance remain implementation/validation work.

API reference: [HttpResponse.detachSocket](https://api.dart.dev/dart-io/HttpResponse/detachSocket.html).
