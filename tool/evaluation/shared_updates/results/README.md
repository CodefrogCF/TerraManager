# Archived acceptance measurements

`acceptance-2026-10.zip` retains the original sanitized Shared Care JSON/JSONL/CSV
and password-backup CSV evidence from October 2026. `manifest.json` records each
original relative name, size and SHA-256; file bytes and earlier classifications
are unchanged. This is historical evidence, not a current benchmark or test suite.

Reader-facing results: [Shared Care](../../../../docs/testing/shared-care-updates.md),
[password backups](../../../../docs/testing/password-backups.md).
Unpack outside the source tree before analysis. With the archive extracted as
`/tmp/tm-measurements`, the existing analyzers accept these input paths:

```sh
python3 tool/evaluation/shared_updates/analyze_integrated.py \
  /tmp/tm-measurements/data/shared-care-integrated-sse-matrix-2026-10-18.json \
  --resources /tmp/tm-measurements/data/shared-care-integrated-pi-resources-2026-10-18T145330Z.jsonl \
  --resources /tmp/tm-measurements/data/shared-care-integrated-pi-resources-2026-10-18T174803Z.jsonl \
  --output-prefix /tmp/matrix-summary
```

Use `analyze_integrated_soak.py` for the reopen-soak JSON and corresponding
resource capture. The current parent-directory capture helpers are for new runs;
`../frozen/` keeps exact historic tool revisions referenced by old source hashes.
Do not combine incomplete coverage, different process starts or unmatched browser
versions into one accepted comparison. Never add credentials, cookies, private
backups or response bodies to published measurement archives.
