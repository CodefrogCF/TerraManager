# Roadmap

Current work and acceptance criteria live in
[GitHub Issues](https://github.com/CodefrogCF/TerraManager/issues).
Completed releases are recorded once in the [changelog](../CHANGELOG.md).
This page does not duplicate issue checklists or infer their current GitHub state.

## Established scope

Standalone Android/Web supports local collections, permanent Box QR labels,
Animal profiles, pictures, care histories, reminders, archives, printable exports
and portable password-protected backups. Shared Care adds a self-hosted collection,
local accounts, role/conflict checks and automatic SSE updates. It does not
synchronize independent standalone collections.

## Follow-up priorities

- Migrate the remaining Android DSL when Flutter/upstream plugins support it;
  retain `android.newDsl=false` until then.
- Bound memory for large protected backup operations and validate the target on
  approximately 4 GiB hardware. Functional large-backup success does not prove
  the memory target.
- Complete outstanding release-candidate/device checks for affected features.
- Validate iOS before advertising support; native desktop releases are not validated.

## Ideas without a committed release

Sensors and environmental history, smart-home integration, breeding/health and
enclosure-maintenance records, assignment history, scheduled/incremental backups,
selective/merge restore and optional remote/device synchronization.
These are proposals, not present capabilities or delivery commitments.
