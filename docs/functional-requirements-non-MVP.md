# Functional Requirements – non-MVP

The following functionality is outside the current TerraManager MVP scope.

## Sensors

- sensor management
- automatic temperature tracking
- automatic humidity tracking
- sensor history
- alerts based on environmental values

## Smart Home

- smart-home integration
- automated heating control
- automated humidity control
- external device integrations

## Synchronization

- user accounts
- cloud synchronization
- multi-device synchronization
- shared terrarium data between users

Manual transfer of a complete TerraManager state through `.tmbackup` files is
supported, but this is not synchronization.

A restore replaces the current local state instead of merging concurrent data
from multiple devices.

## Advanced Backup and Transfer

The following functionality remains outside the current MVP:

- automatic backups
- scheduled backups
- cloud backup
- incremental backups
- selective record restore
- merge restore
- conflict resolution during import
- direct device-to-device synchronization
- automatic synchronization of backup files
- backup encryption
- remote backup storage management

Manual portable backup and full replacement restore are part of the MVP
beginning with v0.6.0.

Backup Format Version 1 supports domain data, appearance settings and Animal
pictures.

## Additional Platforms

- full iOS validation
- optional desktop platform support

## Future Domain Features

Possible future features may include:

- Animal weight history
- shedding history
- health/event tracking
- breeding records
- enclosure maintenance history
- feeding schedules and reminders

These features are not part of the current MVP unless explicitly moved into a
future milestone.