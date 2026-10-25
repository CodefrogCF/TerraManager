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
Standalone release builds do not require network access. Feeding notifications
are optional and off by default; Android 13+ asks for permission only on explicit
opt-in. In-app reminders need no notification permission. The Shared Care link
opens the external browser; neither Web mode schedules system notifications.

### Feeding notifications

Enable per Android device in Settings; this preference and the delivery ledger
are not portable backup settings. One-shot alerts follow the existing interval
or fixed weekday/IANA schedule. A due appointment is reported once, then waits
for a Feeding or schedule change; overdue alerts are not repeated daily.
Changes, archive/delete and collection restore reconcile while the app runs.
Pending alerts survive reboot/app update. Reopen after force stop; battery
restrictions, a blocked channel or manufacturer alarm limits can delay/prevent
alerts. If alerts arrive only after opening the app, check its Android battery
and standby settings; on Samsung, ensure it is not in deep sleep and compare
with the app's battery setting set to Unrestricted. No exact delivery time is
guaranteed, and power-saving restrictions can delay delivery beyond an hour.
App resume preserves due pending alarms; cold starts rearm cached alarms after
force stop. There is no continuously running background or hourly polling
service: Android delivers the scheduled alerts. A saved weekday zone remains
authoritative after travel; changing the device zone does not rewrite the plan.
In-app 24-hour overview suppression does not mute Android notifications.

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
