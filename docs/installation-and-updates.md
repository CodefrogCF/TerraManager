# Installation and Updates

This guide covers the currently validated TerraManager platforms: Android and
Web. iOS, macOS, Linux and Windows are not current supported release targets.

## Obtain a trusted release

Use the TerraManager GitHub Releases page linked from the repository. Each
release should identify its source tag, version/build number and published
artifacts. Compare a downloaded artifact's SHA-256 hash with the value published
for that release when one is provided.

Third-party builds may contain changes not reviewed by the TerraManager
maintainer. Their distributor is responsible for documenting those changes,
signing identity, support and privacy behaviour.

TerraManager v1.0.0 is the first stable MVP release using the permanent
application identity and production signing certificate. Version 1.0.0 keeps
Database Schema Version 5 and Portable Backup Format Version 2.

## Android installation

The release APK is the directly installable Android artifact. Android may ask
the user to allow installation from the application that opened the APK. Only
grant that permission for a release obtained from a trusted source, and disable
it again when it is no longer needed.

The Android App Bundle (`.aab`) is intended for an application store or other
bundle-processing service and is not installed directly on a device.

Official production releases use application ID
`com.codefrog.terramanager`. Compatible updates must use a higher Android build
number and the same production signing certificate. The expected certificate
SHA-256 digest is:

```text
f9bcd66cf622597f8522841682b9cb8ead568cdab84b56b7470f0eb3f298b748
```

Before updating, create a current `.tmbackup` and keep it outside the
application's private storage. Install the newer trusted APK over the current
production-signed installation, start TerraManager and verify the version and
important records. Android rejects an in-place update when the application ID
or certificate differs; do not work around that warning without understanding
the source of the replacement build.

### Transition from pre-v1.0 Android builds

Releases through v0.14.1 used the temporary identifier
`com.example.flutter_application_1`. Development build `0.14.2+34` uses the
permanent identifier but was signed with the Android debug certificate. Neither
installation can be updated in place by the production-signed application.

For either one-time transition:

1. Export and safely store a current `.tmbackup` from the old installation.
2. Keep the old installation until the backup has been verified as far as
   practical.
3. Remove any conflicting permanent-ID debug installation when required.
4. Install the production-signed TerraManager APK.
5. Restore the backup through Settings.
6. Verify Boxes, Animals, FeedingEvents, settings and pictures before deleting
   any remaining old installation or backup copy.

Portable Backup Format Version 2 remains compatible across this identity and
signature transition.

Production-signed builds beginning with `0.14.3+35` already use the permanent
identity and certificate. They can be updated directly to v1.0.0 when the
replacement APK has the expected certificate and the higher build number 39.
Create a current backup before updating even when an in-place update is
available.

## Web installation and updates

A Web release is a static build produced with `flutter build web`. Deploy the
complete `build/web` directory, including the Drift worker and SQLite WASM
files, to one stable HTTPS origin. Do not mix files from different builds.

The Web application stores its data in the active browser profile for that
exact origin. Changing the scheme, hostname, port or browser profile creates a
different storage context. Clearing site data can permanently remove the local
database and settings.

Before deploying or using an updated Web build:

1. Export a current `.tmbackup`.
2. Deploy the complete new build atomically when the host supports it.
3. Reload the application and verify its version and data.
4. Restore the backup only if local browser data is missing or damaged.

The server hosting a Web build may have separate logging and privacy behaviour;
see [PRIVACY.md](../PRIVACY.md).

## Backups during updates

`.tmbackup` archives include application data, settings and Box and Animal
pictures. They are portable between the validated Android and Web platforms but
are not encrypted. Store and transfer them as sensitive files. Restore performs
validated full replacement of the current local state and creates a safety
backup where supported.

For format details and compatibility rules, see
[backup-format.md](backup-format.md).
