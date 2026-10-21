# Release Checklist

This is the canonical release-validation checklist. Use the pinned
[toolchain](toolchain-baseline.md) and a clean source revision.

## Automated checks and artifacts

- [ ] Resolve locked dependencies and generate localizations.
- [ ] Pass formatting, `flutter analyze`, `flutter test` and CI, including the
  ARM64 server job when Shared Care changes.
- [ ] Compile the Drift worker before standalone Web; build both Web entry points
  with local rendering resources.
- [ ] Build Android Debug and production-signed APK/AAB; verify application ID,
  certificate, version/build number, artifact sizes and SHA-256.
- [ ] Confirm strict Gradle locks and `verifyAndroidBuiltInKotlin` still pass.

Commands are in [Development](development.md) and
[Android release signing](android-release-signing.md).

## Functional acceptance

- [ ] Verify changed workflows on Android and affected desktop/mobile browsers;
  include English/German, narrow screens and enlarged text for UI changes.
- [ ] Check persistence, archive/restore, QR, pictures and care histories where touched.
- [ ] For backup changes, verify legacy formats, large media, cancellation,
  wrong password/corruption, safety-copy failure and unchanged data on failure.
  Use the [backup validation summary](testing/password-backups.md).
- [ ] For Shared Care, verify trusted HTTPS, automatic updates, conflicts,
  connection recovery, role/session handling and collection restore using
  disposable data. See [Shared Care acceptance](testing/shared-care-updates.md).
- [ ] Record only issue-required results and outstanding checks in
  [Validation](testing/validation.md). A build does not establish a device result.

Large password-protected backups currently have proportional memory costs.
The separate bounded-memory optimization does not block this release-validation
issue when the limitation is documented and functional/integrity gates pass.
Do not claim the deferred 64 MiB / approximately 4 GiB target is satisfied.

## Compatibility and publication

- [ ] Review schema/backup compatibility, permissions, network behavior and signing.
- [ ] Update version/build and changelog; align homepage, both guides, PDFs and
  screenshots with the release. Keep Store text/screenshots consistent with the
  signed candidate; check its rating link and browser fallback on a device.
- [ ] Review privacy/support/security text when behavior changes.
- [ ] Test update with an external backup; publish matching artifacts and release
  notes, then verify download links.

See [Installation and updates](installation-and-updates.md) for the user procedure.
