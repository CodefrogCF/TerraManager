# Validation summary

This summary retains acceptance evidence, not implementation diaries. Historical
counts describe the recorded revision; repeat affected checks after changes.
GitHub issue status remains in [Issues](https://github.com/CodefrogCF/TerraManager/issues).

| Scope | Established evidence | Remaining boundary |
| --- | --- | --- |
| #186, #226-#230: efficient Shared Care updates | Transport comparison/ADR, committed revisions, targeted reads, authenticated SSE, fallback/recovery; repeated Pi matrix, resource budgets, 30-minute soak and physical lifecycle checks completed by 2026-10-21. | Recorded fixture/browser scope; S22 Firefox excluded from trusted HTTPS. [Details](shared-care-updates.md). |
| #212: Built-in Kotlin | Effective built-in compilation verified for 12 modules; automated suite, strict-lock Android builds, signed APK/AAB and both Web builds passed. Advisory comparison introduced no new pair. | `android.newDsl=false` and legacy DSL dependencies remain separate work; existing build/test advisories remain. [Details](android-build.md). |
| #203-#207: protected backups | Authenticated container/legacy/failure coverage; large native, mobile-Web and Shared Care restores. | Proportional memory and recorded release-candidate evidence gaps. [Details](password-backups.md). |
| #231: overview menus | Standalone Box/Animal menus omit Rename; edit pages still rename. Context-menu regression passed. | Target-device interaction remains part of release checks. |
| #232: creation pictures | 20 widget cases cover Animal/Box creation, DE/EN, optional picture, crop cancellation/failure, upload rejection/lost reply, retry without duplicate creation and busy-state guards. | Camera/gallery/browser file chooser use controlled fakes; verify actual pickers on target devices. |
| #233: reminder actions | Standalone/Shared Care: existing Feeding workflow, 24-hour expiry and persistence, per-Animal/account isolation, unchanged schedule/detail reminders, DE/EN list/grid and failure/retry coverage. | Device interaction remains a release check. |
| #234: due-summary outlines | Eight rendering cases cover both modes, themes, one/two due Animals, unchanged geometry and expand/collapse. | Physical display acceptance follows release checks. |
| #235-#237: overview sorting and controls | Both modes: all Box sort orders, live assignment changes, persisted personal setting and backup compatibility; scanner workflows, archive navigation and floating controls at narrow/landscape/desktop sizes with enlarged text. | Physical Android camera and browser interaction remain release checks. |

## Recorded automated gates

- #231/#232/#234 (2026-10-21): 172 focused/regression tests, full analysis,
  20 Chrome widget tests, Shared Care Web release and Android Debug build passed.
  The Chrome run used local Windows test-runner workarounds; they are not an
  application requirement or proof of native picker behavior.
- Offline-save regression correction (2026-10-21): the test now scrolls to the
  lazily built Save button and confirms reconnection does not replay a write.
  Full suite: **1,324 passed, one opt-in network test skipped** on Flutter 3.47.2 /
  Dart 3.13.2, Windows. Changed-file analysis and formatting passed.

- #233 (2026-10-21): full suite plus affected-file recheck cover 1,341 passing
  cases; 1 opt-in network test skipped. Full analysis, both Web release builds
  and pure-Dart Windows server build passed. Both guide PDFs remain four pages.
  Android interaction and the Linux Docker image were not exercised here.

- #235-#237 (2026-10-21): **1,360 tests passed, 1 opt-in network test skipped**
  on Flutter 3.47.2 / Dart 3.13.2, Windows. Full analysis, formatting, both Web
  release builds and pure-Dart Windows server build passed. DE/EN guide PDFs
  remain four pages each; physical Android scanning and Linux Docker build
  were not exercised here.

## Recording future changes

For each issue, record requirement, command/device, result and any unverified
boundary. Retain only measurements needed by its acceptance criteria. Do not
duplicate CI logs, delivery packaging, temporary workspace setup or each failed
intermediate attempt. Keep reproducible raw data separately from reader-facing
results. General commands belong in [Development](../development.md); publishing
gates belong in the [release checklist](../release-checklist.md).
