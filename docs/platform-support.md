# Platform Support

| Platform / mode | Status | Storage |
| --- | --- | --- |
| Android standalone | Validated release target | App-private SQLite; local preferences |
| Standalone Web | Validated release target | SQLite WASM/worker in the browser profile |
| Shared Care Web + ARM64 server | Validated self-hosted mode | Server-owned SQLite; account preferences on server |
| iOS | Planned; build/device validation outstanding | Not a validated release |
| Native Windows, macOS, Linux apps | Not validated release targets | Source scaffolding is not support evidence |

## Android

The permanent application ID is `com.codefrog.terramanager`. Production updates
require the established signing identity and a higher build number. See
[Installation and updates](installation-and-updates.md) and
[Android release signing](android-release-signing.md).
Camera/gallery/file actions use the corresponding platform facilities.
Standalone release builds do not require network or notification permission;
the Shared Care link opens the external browser.

## Web

- Standalone data belongs to one scheme/host/port and browser profile. Clearing
  site data or using private browsing can lose persistence; keep external backups.
- Deploy the complete build, including `sqlite3.wasm` and the generated Drift
  worker. An in-memory fallback is not persistent storage.
- Camera use requires browser/device support, permission and a secure context.
  Shared Care additionally requires native `BarcodeDetector` support for QR
  scanning; manual Box selection remains available. No public decoder CDN is used.
- Camera picture selection and torch controls appear only when supported.
- Save destinations and fallback downloads depend on the browser/OS.
- Protected backups may take minutes and require memory proportional to the
  archive. Large files can fail on low-memory clients; failed/cancelled restore
  leaves the collection unchanged.

Shared Care uses trusted LAN HTTPS, a supported browser and a reachable server.
Hidden/disconnected clients reconcile on return; edits are not queued offline.
Appearance and sorting are account preferences, not a browser collection database.

## Portability

Android, standalone Web and Shared Care exchange portable `.tmbackup` collections.
Restore is full replacement. Older formats remain importable as described in the
[backup format](backup-format.md); Shared Care accounts/sessions/audit are excluded.
