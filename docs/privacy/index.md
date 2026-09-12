---
layout: default
title: TerraManager
---

# TerraManager Privacy Policy

**Effective date:** September 12, 2026
**Application:** TerraManager
**Developer:** CodefrogCF
**Privacy and support contact:** See the TerraManager project repository for the current contact and support channels.

## 1. Overview

TerraManager is a local-first application for managing terrarium animals and their enclosures.

Privacy is a core design principle of TerraManager.

The current version does not provide or require:

* a TerraManager user account;
* a user profile;
* a TerraManager-operated backend;
* mandatory cloud storage or synchronization;
* advertising;
* advertising identifiers;
* user profiling;
* TerraManager-operated analytics;
* TerraManager-operated telemetry;
* crash-reporting services;
* subscription services.

Animal and collection data is intended to remain under the user's control.

## 2. Data stored by TerraManager

TerraManager stores information that the user enters or creates while managing a collection.

Depending on how the application is used, this may include:

* animal records;
* animal names and species information;
* sex and birth or hatch information;
* animal notes;
* animal pictures;
* enclosure or Box records;
* enclosure dimensions;
* associations between animals and Boxes;
* creation and modification dates;
* FeedingEvents and feeding history;
* QR identifiers;
* application preferences and settings.

This information is application data and is not transmitted to a TerraManager-operated server.

## 3. Local storage

### Android

On Android, TerraManager stores its collection database, application settings and internally managed files locally on the user's device.

The Android production release does not request the Android `INTERNET` permission.

As a result, the Android production application cannot use ordinary network connections to transmit TerraManager application data to TerraManager, the developer, advertising services or analytics services.

TerraManager does not require an Internet connection for its normal collection-management functionality.

### Web

When TerraManager is used as a Web application, application data is stored locally within the active browser environment where supported.

Browser storage is controlled by the browser and the operating system.

Clearing browser data, using private browsing modes, resetting browser storage or other browser-management actions may remove locally stored TerraManager data.

The website or hosting provider used to deliver the TerraManager Web application may process technical connection information, such as IP addresses, request timestamps or browser information, as part of normal web hosting.

Such hosting-level processing is separate from TerraManager's collection-management functionality and is subject to the privacy terms of the respective hosting provider.

## 4. Data collection and sharing

TerraManager does not operate a server or backend that receives users' animal or collection data.

Animal, Box, FeedingEvent, picture and application-setting data is processed locally by TerraManager.

TerraManager does not:

* sell user data;
* sell collection data;
* use collection data for advertising;
* create advertising profiles;
* share collection data with advertisers;
* operate behavioural analytics based on collection data.

Data may leave TerraManager only when the user explicitly initiates an action that transfers or exports data.

Examples include:

* exporting a TerraManager backup;
* saving an exported file;
* saving a QR-code image;
* selecting a file through an operating-system file picker;
* choosing another application or operating-system service as an export or sharing destination.

Once data is deliberately transferred to another application, storage provider, operating-system component or other third-party destination, that service may process the data according to its own privacy terms.

TerraManager does not control third-party applications or services selected by the user.

## 5. Backups

TerraManager allows users to create backups of their locally stored application data.

Backups are created only as a result of a user-initiated action.

TerraManager does not automatically upload backups to a TerraManager server or cloud service.

The user chooses where an exported backup is stored or transferred.

TerraManager backup archives are not encrypted by TerraManager. Anyone who
obtains access to an exported backup may be able to read the collection data
and media contained in it.

Users should therefore store and transfer backup files using appropriately
protected storage and communication methods.

Users are responsible for protecting backup files that they create, including any copies stored outside TerraManager.

A backup may contain collection information stored in TerraManager and should therefore be treated according to the sensitivity of the information entered by the user.

## 6. Pictures

TerraManager allows pictures to be associated with animal records.

Pictures selected or created for use with TerraManager are processed for use within the application and stored as part of the user's locally managed TerraManager data.

TerraManager does not automatically upload animal pictures to a TerraManager server.

If the user exports, shares or backs up data containing pictures, those files may be processed by the destination selected by the user.

## 7. QR codes and camera access

TerraManager uses QR codes to associate physical enclosures with Box records in the application.

On Android, TerraManager requests camera access for QR-code scanning and for user-initiated camera functionality where applicable.

QR-code recognition is performed on the device.

TerraManager does not transmit camera images or decoded TerraManager QR contents to a TerraManager-operated server.

Camera access is requested only when functionality requiring the camera is used or when the operating system requires permission for that functionality.

The camera permission can be managed through the Android system settings.

## 8. Android permissions

The Android production release is designed to request only permissions required for application functionality.

The current production package may declare the following permissions:

### Camera

`android.permission.CAMERA`

Used for QR-code scanning and user-initiated camera functionality.

### Legacy external-storage write access

`android.permission.WRITE_EXTERNAL_STORAGE`

This permission is declared with:

`maxSdkVersion="28"`

It therefore applies only to Android 9 / API level 28 and older.

It exists for compatibility with file-export functionality on older supported Android versions.

It does not apply to Android 10 or newer.

### Android internal compatibility permissions

Android or AndroidX libraries may add application-specific internal permissions used to securely manage Android components.

For example, the production package may contain an application-specific `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.

Such permissions do not provide TerraManager with access to personal user information.

## 9. Permissions not requested by the Android production release

The current Android production release does not request:

* Internet access;
* network-state access;
* location access;
* contacts access;
* microphone access;
* access to Android user accounts;
* system notification permission;
* unrestricted external-storage read access.

Some Android system components, file pickers or media pickers selected by the user may provide temporary access to individual files without granting TerraManager broad storage permissions.

## 10. QR scanning technology

TerraManager uses third-party open-source software components to provide QR-code scanning and other application functionality.

QR recognition in the Android application is performed locally on the device.

The Android production release does not request Internet access, so TerraManager's Android application process does not use ordinary network connections to transmit QR images, decoded QR contents or collection information during QR scanning.

Third-party components remain subject to their respective software licences.

## 11. Feeding reminders

TerraManager can display feeding-related reminder information within the application.

The current version does not require Android system-notification permission for this functionality.

Feeding reminder calculations are based on locally stored TerraManager data and are processed locally.

## 12. No account or registration

TerraManager does not require users to register an account.

There is no TerraManager username, password or online user profile required to use the application.

Because TerraManager does not operate a user-account backend, there is no TerraManager account database containing users' animal collections.

## 13. No advertising

TerraManager does not contain advertising.

It does not integrate advertising networks for the purpose of displaying targeted or untargeted advertisements.

Collection data is not used to create advertising profiles.

## 14. No TerraManager analytics or tracking

TerraManager does not operate an analytics or user-tracking system.

The developer does not receive usage histories describing how users navigate their collections, which animals they manage, when they record feedings or what information they enter into TerraManager.

The Android production release does not request Internet access.

## 15. Data retention

Locally stored TerraManager data remains on the user's device or within the relevant browser environment until it is removed by the user, by the operating system, by the browser or through application-management actions.

Depending on the platform, data may be removed by actions such as:

* deleting records within TerraManager;
* clearing application data;
* clearing browser storage;
* uninstalling the application;
* deleting exported backup files;
* deleting exported pictures or documents.

Uninstalling TerraManager does not necessarily delete backup files or other files that the user previously exported to locations outside the application's private storage.

Those exported files must be removed separately by the user.

## 16. Data transfer to another device

TerraManager supports transferring collection data between devices through its backup and restore functionality.

The transfer is initiated and controlled by the user.

TerraManager does not operate an intermediary synchronization server for this process.

The user is responsible for selecting an appropriate and secure method for transferring the backup file between devices.

## 17. Personal information entered by users

TerraManager is intended to manage animals and enclosures, not personal profiles.

However, free-text fields such as animal notes may technically allow a user to enter arbitrary information.

Users should avoid entering personal or sensitive information that is unnecessary for managing their collection.

Any such information entered voluntarily is treated in the same way as other TerraManager data and remains part of the locally stored application data unless the user deliberately exports or transfers it.

## 18. Third-party software

TerraManager uses third-party libraries and platform components to provide functionality such as:

* local database storage;
* camera and image selection;
* QR generation and scanning;
* image processing;
* file selection and saving;
* backup creation and extraction.

The inclusion of a software library does not mean that TerraManager provides that library with users' collection data over a network.

On Android, the production application does not request the `INTERNET` permission.

Software licences and acknowledgements for third-party components are available through the project's dependency information and applicable open-source licence notices.

## 19. Operating-system and third-party services

Some actions intentionally hand data to services controlled by the operating system or selected by the user.

Examples may include:

* the Android photo picker;
* the Android file picker;
* a file manager;
* a gallery application;
* a cloud-storage application explicitly selected by the user;
* another application chosen as an export destination.

These applications and services operate independently of TerraManager.

Their handling of files or other information is governed by their own privacy policies and settings.

## 20. Security

TerraManager is designed around local data storage, which limits automatic exposure of collection data to remote services.

However, local storage does not remove all security risks.

Anyone with sufficient access to an unlocked device, exported backup or other exported TerraManager files may potentially access information contained in those files.

Users should therefore protect their devices and exported backups using appropriate operating-system security measures.

## 21. Changes to this Privacy Policy

This Privacy Policy may be updated when TerraManager's functionality, supported platforms or data-processing behaviour changes.

Material changes affecting data collection, data sharing, networking, accounts, analytics, advertising or cloud functionality will be reflected in an updated version of this document.

The effective date at the top of this document indicates when the current version became effective.

## 22. Contact

Questions about TerraManager's privacy behaviour can be submitted through the
current support channels:

[TerraManager Support](https://github.com/CodefrogCF/TerraManager/blob/main/SUPPORT.md)

When TerraManager is distributed through an application store, the current developer or support contact provided on the applicable store listing may also be used.
