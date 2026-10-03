# Release Checklist

This document is the canonical release-validation checklist for TerraManager.

Release history belongs in `CHANGELOG.md`.
Development and issue-level validation belongs in `development.md`.
Installation and update guidance belongs in `installation-and-updates.md`.

## Automated quality gates

Run from a clean source state:

```text
flutter clean
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

For documentation changes also run:

```text
flutter test test/platform/public_documentation_test.dart
```

For CI or toolchain changes also run:

```text
flutter test test/platform/toolchain_quality_gates_test.dart
```

## Release builds

Build the validated release targets:

```text
flutter build apk --debug
flutter build apk --release
flutter build web
```

When preparing an Android production release, follow
[Android release signing](android-release-signing.md).

## Manual regression

Validate the affected workflows on every supported target platform.
At minimum review:

- application startup and persistence
- Box and Animal workflows
- archive and restore workflows
- QR scanning and export where affected
- backup export and restore where affected
- localization for changed user-visible text
- platform-specific functionality touched by the release

For a release containing password-protected portable backups, record the
following before closing that milestone:

Use the [password backup device check](testing/password-backup-device-check.md)
and its synthetic 252 MiB fixtures for the comparable platform measurements.

- On available physical Android hardware and desktop/mobile browsers, exercise
  plain and protected export/restore with a media-rich backup near 256 MiB.
  Record duration, device RAM and whether the operation completed without
  changing the collection on failure or cancellation. Peak-memory measurements
  remain useful evidence, but the separate bounded-memory follow-up owns the
  former 64 MiB / approximately 4 GiB optimization target.
- Cross-client standalone and Shared Care imports, including portable formats
  1 and 2, wrong password, tampering, truncation, cancellation and safety-copy
  failure; verify that failed operations leave the collection unchanged.
- Check that no password appears in settings, logs, API requests or the file;
  inspect native temporary files and browser download fallbacks for plaintext.
- Compare final signed APK/AAB and both Web bundles with the Issue #118
  baseline using the pinned toolchain; record byte sizes and tool versions.
- Regenerate and inspect both downloadable guide PDFs after updating the
  English and German guide data.

The memory optimization goal is not a cryptographic or data-integrity claim.
The separate follow-up work to bound memory use for large password-protected
backup operations does not block this release-validation issue. It may remain
open when the current proportional-memory behavior is documented for users and
the release evidence does not claim bounded-memory operation. The security,
legacy compatibility, large-media functional checks, unchanged-data failure
behavior and final artifact checks above still apply.

Do not duplicate feature-specific test matrices here. Feature-specific regression
coverage belongs to the implementation issue and automated tests.

## Compatibility review

Review whether the release changes:

- Database Schema Version
- Portable Backup Format Version
- application identity
- Android signing requirements
- device permissions
- network behaviour
- supported platforms
- backup compatibility

Technical format details remain authoritative in:

- [Data model](data-model.md)
- [Backup format](backup-format.md)
- [Platform support](platform-support.md)
- [Installation and updates](installation-and-updates.md)

## Public documentation review

For Store Presence Refresh, review the German/English descriptions and the
localized screenshot contact sheet together. Follow
[the Store asset maintenance guidance](documentation-maintenance.md#store-listing-assets), recheck current
Play requirements and publish only with the Android build that contains the
shown workflows. Confirm the voluntary rating link and browser fallback on
a signed candidate installed on a physical phone. Publication is a release-owner
step; the asset-generation tools do not upload or publish anything.

For every release that changes visible behaviour, review:

- project homepage
- English and German visual guides
- English and German downloadable manuals
- installation/update documentation
- README and project documentation
- privacy/support/security documentation when relevant

Update screenshots when the existing image would misrepresent the current UI or
workflow.

Keep English and German guides aligned.

See [Documentation maintenance](documentation-maintenance.md) for ownership and
maintenance rules.

## Release metadata

Before publishing:

- update the application version and build number
- update CHANGELOG.md
- verify that each localized visual guide links to the matching localized manual
- confirm current Database Schema Version
- confirm current Portable Backup Format Version
- verify release artifact names
- verify Android signature where applicable
- record artifact hashes where required
- prepare the GitHub Release description

## Final validation

The release is ready only when:

- automated quality gates pass
- supported release builds complete
- required manual regression is complete
- documentation review is complete
- installation/update guidance remains accurate
- compatibility notes are current
