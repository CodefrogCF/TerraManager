# TerraManager

TerraManager manages terrarium Boxes, Animals, pictures and care histories.
It is built with Flutter, supports Android and Web, and has English and German
interfaces. iOS and native desktop releases are not validated.

## Choose a mode

| Mode | Data and connection |
| --- | --- |
| Standalone Android / Web | Collection stays on the device or browser profile; works offline. |
| Shared Care Web | Several caregivers use one collection on their own LAN server through authenticated HTTPS. Changes arrive automatically through SSE. |

Standalone collections and Shared Care remain independent. Portable `.tmbackup`
files transfer a complete collection; restore replaces data rather than merging it.
There is no developer-operated cloud, advertising or analytics.

## Features

- Boxes with permanent QR labels, scanning and reassignment.
- Animal profiles, galleries, feeding, weight and shedding histories.
- Interval or weekday feeding reminders, due indicators and feeding schedules.
- Archive, restore, duplication and configurable overview sorting.
- QR exports and Animal PDF exports: compact labels or A4 profiles with history
  and optional gallery pages.
- Portable backups with optional password protection.
- Shared Care accounts, role checks, conflict protection and administrator audit.

## Documentation and downloads

- [Homepage and downloads](https://codefrogcf.github.io/TerraManager/)
- [German guide](docs/guide/index.md) / [English guide](docs/guide/en/index.md)
- [Installation and updates](docs/installation-and-updates.md)
- [Developer documentation](docs/project-documentation.md)
- [Release history](CHANGELOG.md)
- [Support](SUPPORT.md) / [Security](SECURITY.md) / [Contributing](CONTRIBUTING.md)
- [Privacy](PRIVACY.md) / [Datenschutz](PRIVACY.de.md)
- [GPL-3.0-or-later license](LICENSE)
