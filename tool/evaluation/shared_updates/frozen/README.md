# Historical capture tools

These byte-preserved revisions make the retained 2026-10-18 metadata traceable.
The SHA-256 values were checked against each capture's `toolSha256` object.
Use the current parent-directory helpers for new work.

- `matrix-2026-10-18/`: complete 12-trial production release matrix, Chrome .84;
  JSON `/changes` bodies were excluded and no native DOM timestamps existed.
- `frame-initial-2026-10-18/`: first supplementary frame run, Chrome .85;
  frame evidence is valid, but its native overview timing is missing because
  the first semantics observer did not recognize merged overview-row text.

The initial-frame revision was reconstructed from the bounded follow-up changes
and written only after **every recorded source hash matched exactly**, including
the original line endings. No missing observation was filled in. The current
revision recognizes merged rows, checks each view before measurement, records
control-query reads and distinguishes frame elapsed time from OS CPU time.
