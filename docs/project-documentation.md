---
layout: default
title: TerraManager documentation
permalink: /project-documentation.html
---

# TerraManager documentation

TerraManager has two independent storage modes: standalone Android/Web keeps a
local collection; Shared Care Web uses one self-hosted server collection through
an authenticated HTTPS API. Shared Care browsers hold transient view state and
receive change notifications through SSE. Commands and refreshed data use HTTP.

## For users and operators

| Topic | Guide |
| --- | --- |
| Everyday workflows | [German guide](guide/index.md), [English guide](guide/en/index.md) |
| Install, update and transfer data | [Installation and updates](installation-and-updates.md) |
| Supported devices and browser limitations | [Platform support](platform-support.md) |
| Set up, back up and update Shared Care | [Shared Care deployment](shared-care-deployment.md) |
| Report a problem | [Support](https://github.com/CodefrogCF/TerraManager/blob/main/SUPPORT.md) |

## For developers

| Topic | Reference |
| --- | --- |
| Setup, generation and documentation maintenance | [Development guide](development.md) |
| Pinned SDKs and dependency locks | [Toolchain baseline](toolchain-baseline.md) |
| Build and publish | [Release checklist](release-checklist.md), [Android release signing](android-release-signing.md) |
| Decisions and trade-offs | [Architecture decisions](architecture-decisions.md) |
| SQLite entities and migrations | [Data model](data-model.md) |
| Portable and password-protected archives | [Backup format](backup-format.md) |
| Shared client/server boundaries | [Shared Care code organization](shared-care-architecture.md) |
| Routes, authorization and limits | [Shared Care API](shared-care-api.md) |
| Revisions, SSE and recovery | [Change contract](shared-care-change-contract.md) |
| Future work | [Roadmap](roadmap.md) |

## Project policies

[Privacy](privacy/index.md), [Datenschutz](privacy/de/index.md),
[Security](https://github.com/CodefrogCF/TerraManager/blob/main/SECURITY.md),
[Contributing](https://github.com/CodefrogCF/TerraManager/blob/main/CONTRIBUTING.md)
and the [GPL-3.0-or-later license](license/index.md) define the project's policies.
Published changes belong in the [changelog](https://github.com/CodefrogCF/TerraManager/blob/main/CHANGELOG.md).
