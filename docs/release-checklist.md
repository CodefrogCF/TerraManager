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