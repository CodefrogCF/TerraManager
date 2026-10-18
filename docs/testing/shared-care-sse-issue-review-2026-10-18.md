# Shared Care SSE issue review, 2026-10-18

Reviewed the public GitHub issue bodies and states against the local source,
the repeated Pi evaluation, and the separate Issue #226 delivery. GitHub issue
states were read only. Apply/test/commit the implementation ZIP before treating
the delivered code as repository completion.

## Canonical issue set

| Issue | Review | Recommended action |
| --- | --- | --- |
| [#186 Evaluate efficient Shared Care data updates beyond polling](https://github.com/CodefrogCF/TerraManager/issues/186) | Already closed on GitHub at the final read; decision/evaluation evidence recorded: five transports, real Flutter baseline, repeated Pi latency/traffic/CPU/RSS and ADR-037 | Keep the decision/evidence and #226-#230 links as the handoff. Production/device acceptance remains #230. |
| [#226 Shared Care: publish committed resource revisions and conditional change queries](https://github.com/CodefrogCF/TerraManager/issues/226) | Implemented in this delivery: commit-only revisions, replay/reset, private preferences, conditional query/reader and snapshot fences | Apply/test/commit the ZIP, then close this server/API scope. |
| [#227 Shared Care: replace screen polling with a central targeted refresh controller](https://github.com/CodefrogCF/TerraManager/issues/227) | Shared controller and UI integration remain | Keep open; next implementation step. |
| [#228 Shared Care: deliver authenticated change notifications through SSE](https://github.com/CodefrogCF/TerraManager/issues/228) | Production stream endpoint/browser adapter remain; the tested lab is a prototype | Keep open. |
| [#229 Shared Care: reconcile SSE reconnects, browser lifecycle and polling fallback](https://github.com/CodefrogCF/TerraManager/issues/229) | Connection policy, lifecycle and application reconciliation remain | Keep open. |
| [#230 Shared Care: validate SSE performance and resource bounds on Raspberry Pi](https://github.com/CodefrogCF/TerraManager/issues/230) | Lab baseline/analysis exists; integrated production Flutter, physical browser, scale and memory-bound acceptance remain | Keep open; include measured reference values and proposed resource budgets. |

## Older overlapping issues

| Older issue | Replacement | Requirements to retain |
| --- | --- | --- |
| [#222 Shared Care: introduce versioned changes and targeted data refresh](https://github.com/CodefrogCF/TerraManager/issues/222) | #226 server/API + #227 controller; #229 connection policy | Commit-only publication, backup-generation separation, races, local clock, coalescing, no suppression of another device signed in to the same account |
| [#223 Shared Care: deliver authenticated invalidations through SSE](https://github.com/CodefrogCF/TerraManager/issues/223) | #228 | Origin/cookie rules, fragmented EventSource delivery, slow-consumer bounds, revocation and disconnect cleanup |
| [#224 Shared Care: handle reconnects, lifecycle and polling fallback](https://github.com/CodefrogCF/TerraManager/issues/224) | #229 | Applied/received cursor separation, restored ID reuse, hidden tabs, jitter and no offline write queue |
| [#225 Shared Care: add multi-client update performance regression coverage](https://github.com/CodefrogCF/TerraManager/issues/225) | #230 | Real Flutter build/frame measurements, 1/3/5/10 clients, physical browsers, upkeep and CPU/RSS evidence |

The consolidated bodies retain these requirements. Close #222-#225 as
superseded/duplicates after linking the replacements; their end-to-end work
continues in the canonical issue set.

## Copyable comments for the older issues

### #222

```markdown
Superseded by #226 (committed server revisions and conditional queries) and #227
(central targeted refresh controller). Connection/lifecycle policy is tracked in
#229. The consolidated acceptance criteria retain the requirements from this issue.
```

### #223

```markdown
Superseded by #228. Its consolidated scope retains authenticated same-origin SSE,
cookie/origin checks, fragmented EventSource delivery, bounded queues, revocation
and disconnect cleanup. Production streaming remains tracked there.
```

### #224

```markdown
Superseded by #229. Its consolidated scope retains applied/received cursor separation,
replay/reset, restore ID reuse, browser lifecycle, jitter, polling fallback and the
existing write policy without introducing an offline write queue.
```

### #225

```markdown
Superseded by #230. Its consolidated scope retains production Flutter/frame metrics,
the 1/3/5/10-client matrix, physical browsers, upkeep/fallback traffic and separate
Dart/Caddy CPU/RSS evidence, including long-term reconnect memory checks.
```

## Additional issues

No additional SSE implementation issue is needed now. RSS growth and remaining
real-Flutter abort classification fit #230. A separate defect issue would be
justified by a reproducible production leak or application-visible failed read;
the present counters and synthetic control do not establish either defect.

This review covers update/SSE issues #186 and #222-#230. The Android DSL
follow-up #221 has a separate build/toolchain scope.

## Evidence

- [Corrected repeated Pi comparison](shared-care-sse-comparison-2026-10-18.md)
- [Real Flutter baseline and five-transport pilot](shared-care-update-evaluation-pi-2026-10-17.md)
- [Issue #226 API contract](../shared-care-change-contract.md)
- [Consolidated replacement bodies](shared-care-sse-implementation-issues.md)
