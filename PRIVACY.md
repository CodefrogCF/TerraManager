# TerraManager Privacy Notice

**Effective date:** 2026-09-09

TerraManager is a local-first application. The current project does not
provide a TerraManager-operated account system, backend, cloud synchronization,
advertising, analytics, telemetry or crash-reporting service.

This notice describes the official TerraManager source and release artifacts.
A third party that modifies, redistributes or hosts TerraManager is responsible
for documenting any additional data processing it introduces.

## Data stored by TerraManager

TerraManager stores application data locally on the device or in the active
browser profile. Depending on how the application is used, this may include:

- Box names, QR identifiers, dimensions and pictures
- Animal names, biological information, notes, pictures and Box assignments
- FeedingEvents and optional feeding-reminder configuration
- appearance, language, name-order and overview-sorting settings

Generated Box QR codes contain the stable Box QR identifier needed to resolve
the Box inside TerraManager. They do not contain the full Box or Animal record.

The Android Release application does not request the Android `INTERNET`
permission. Debug and Profile builds request it for Flutter development tools
such as hot reload; those builds are not production release artifacts.

## Permissions and system capabilities

TerraManager requests access only when a related feature is used. Availability
and the exact system prompt depend on the platform and operating-system
version.

| Access | Purpose | When used |
|---|---|---|
| Camera | Scan Box QR codes and take Box or Animal pictures | After the user opens a scanner or chooses Camera |
| Camera light | Illuminate QR codes in poor lighting | Only after the user activates the scanner light control on supported devices |
| Photos or gallery | Select pictures and save exported QR images | After the user chooses Gallery or saves a QR image |
| Files or documents | Export and select `.tmbackup` files | After the user starts Backup or Restore |
| Printing | Pass a generated QR document to the system or browser print service | After the user chooses Print |
| Local storage | Persist the database, pictures and application settings | During normal application use |

TerraManager does not request location, contacts, microphone, account or system
notification access. Feeding reminders are shown only inside the application.

Operating-system photo pickers, file providers, print services and browsers are
separate components. Their providers may process data according to their own
privacy terms when the user deliberately sends data to them.

## Backups and exported files

A `.tmbackup` file is a portable archive containing the exported TerraManager
database state, settings and associated Box and Animal pictures. Current
backups are **not encrypted**. Anyone who can access a backup may be able to
read its contents.

Users control where a backup is saved and whether it is copied or shared.
Backups should be kept in a trusted, access-controlled location. Do not attach
a real backup to a public issue. TerraManager may create a safety backup before
a restore, and a successful restore replaces the current local application
state with the validated backup state.

## Retention and deletion

Local records remain until they are edited, deleted, replaced through Restore,
or the application's local storage is removed. Uninstalling the Android app or
clearing the Web origin's browser data can permanently remove local data when
no external backup exists.

Copies previously exported by the user are not deleted when local application
data is removed. They must be deleted separately from their chosen storage
locations.

## Web hosting

The Web build stores its application data in browser storage associated with
the deployment origin and browser profile. The server hosting the static Web
application necessarily delivers application files and may keep technical
access logs or use other infrastructure outside TerraManager. Consult the
host's privacy notice. Operators of third-party TerraManager deployments must
disclose their own hosting and data-processing practices.

## Changes and questions

Material privacy changes will be documented in the repository and release
notes. General questions can be opened through the support process in
[SUPPORT.md](SUPPORT.md). Do not include private Animal data, pictures, backup
archives, passwords or signing material in a public report.

