import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../core/database/enums/animal_category.dart';
import '../../../core/database/validation/animal_environmental_limits.dart';
import '../../../core/qr/qr_validator.dart';
import '../../feedings/domain/feeding_weekday_schedule.dart';
import '../domain/backup_data.dart';
import '../domain/backup_timestamps.dart';
import '../domain/backup_enum_codec.dart';
import '../domain/backup_format.dart';
import '../domain/backup_manifest.dart';
import '../domain/backup_settings.dart';
import 'backup_validation_exception.dart';
import 'validated_backup.dart';

typedef BackupQrIdValidator = bool Function(String qrId);

class BackupValidationService {
  final BackupQrIdValidator qrIdValidator;
  final int? maxExpandedBytes;
  final String? legacyTimeZone;
  final bool requireLegacyTimeZone;

  BackupValidationService({
    BackupQrIdValidator? qrIdValidator,
    this.maxExpandedBytes,
    this.legacyTimeZone,
    this.requireLegacyTimeZone = false,
  }) : qrIdValidator = qrIdValidator ?? isValidBoxQrId;

  ValidatedBackup validate(Uint8List bytes) =>
      _validate(InputMemoryStream(bytes), closeArchiveEntries: true);

  /// Validates a browser upload before confirmation without retaining decoded
  /// pictures. The caller only needs the counts; the server validates and
  /// reads the media again before replacing the collection.
  ValidatedBackup validatePreview(Uint8List bytes) => _validate(
    InputMemoryStream(bytes),
    closeArchiveEntries: true,
    retainMediaBytes: false,
  );

  /// Validates a caller-owned stream without loading the complete ZIP.
  /// The caller closes the stream after this method returns.
  ValidatedBackup validateStream(InputStream input) =>
      _validate(input, closeArchiveEntries: false);

  /// File-backed encrypted inputs can re-read media after validation without
  /// retaining every decoded image in memory.
  ValidatedBackup validateLazyStream(
    InputStream input, {
    void Function()? onDispose,
  }) => _validate(
    input,
    closeArchiveEntries: false,
    retainMediaBytes: false,
    onDispose: onDispose,
  );

  ValidatedBackup _validate(
    InputStream input, {
    required bool closeArchiveEntries,
    bool retainMediaBytes = true,
    void Function()? onDispose,
  }) {
    if (input.length == 0) {
      throw const BackupValidationException(
        code: BackupValidationErrorCode.invalidArchive,
        message: 'Backup file is empty.',
      );
    }

    final Archive archive;
    final expectedEntries = <String, (int, int)>{};

    try {
      // Inspect the central directory before ZipDecoder can expand symlinks
      // or deduplicate names. Shared restores accept archives from browsers.
      final directory = ZipDirectory()..read(input);
      final seen = <String>{};
      var remaining = maxExpandedBytes;
      for (final header in directory.fileHeaders) {
        final name = header.filename;
        final portablePath = name.endsWith('/')
            ? name.substring(0, name.length - 1)
            : name;
        if (!_isSafeArchivePath(portablePath)) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.unsafeArchivePath,
            message: 'Backup contains an unsafe archive path: $name',
          );
        }
        if (!seen.add(name)) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.duplicateArchiveEntry,
            message: 'Backup contains duplicate archive entry: $name',
          );
        }
        if (name.endsWith('/') &&
            (header.uncompressedSize != 0 || header.crc32 != 0)) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.invalidArchive,
            message: 'Backup contains a non-empty directory entry: $name',
          );
        }
        expectedEntries[name] = (header.uncompressedSize, header.crc32);
        if (((header.externalFileAttributes >> 16) & 0xf000) == 0xa000) {
          throw const BackupValidationException(
            code: BackupValidationErrorCode.invalidArchive,
            message: 'Backup contains a symbolic link.',
          );
        }
        if (remaining != null) {
          if (header.uncompressedSize < 0 ||
              header.uncompressedSize > remaining) {
            throw const BackupValidationException(
              code: BackupValidationErrorCode.invalidArchive,
              message: 'Expanded backup is too large.',
            );
          }
          remaining -= header.uncompressedSize;
        }
      }
      // archive 4.0.x accepts `verify: true` but does not currently check
      // entry CRCs. Verify all entries consumed by restore explicitly.
      input.reset();
      archive = ZipDecoder().decodeStream(input);
    } on BackupValidationException {
      rethrow;
    } catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidArchive,
        message: 'Backup file is not a valid ZIP archive.',
        cause: error,
      );
    }

    final files = <String, ArchiveFile>{};

    for (final entry in archive.files) {
      final name = entry.name;

      // Explicit directory entries do not contain
      // application data.
      if (name.endsWith('/')) {
        continue;
      }

      if (!_isSafeArchivePath(name)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.unsafeArchivePath,
          message: 'Backup contains an unsafe archive path: $name',
        );
      }

      if (files.containsKey(name)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.duplicateArchiveEntry,
          message: 'Backup contains duplicate archive entry: $name',
        );
      }

      files[name] = entry;
    }

    final manifestFile = _requiredFile(files, BackupFormat.manifestFileName);

    final dataFile = _requiredFile(files, BackupFormat.dataFileName);

    final settingsFile = _requiredFile(files, BackupFormat.settingsFileName);

    final manifestJson = _decodeJsonObject(
      manifestFile,
      BackupFormat.manifestFileName,
    );

    final dataJson = _decodeJsonObject(dataFile, BackupFormat.dataFileName);

    final settingsJson = _decodeJsonObject(
      settingsFile,
      BackupFormat.settingsFileName,
    );

    bool hasLegacyTimestamps;
    try {
      hasLegacyTimestamps = BackupTimestamps.normalize(
        dataJson,
        legacyTimeZone: legacyTimeZone,
        requireZone: requireLegacyTimeZone,
      );
      BackupTimestamps.normalize(manifestJson, legacyTimeZone: legacyTimeZone);
    } catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidArchive,
        message: error is FormatException
            ? error.message
            : 'Invalid source time zone.',
        cause: error,
      );
    }
    final manifest = _parseManifest(manifestJson);

    _validateManifest(manifest);

    final data = _parseData(dataJson);

    final settings = _parseSettings(settingsJson);

    _validateSettings(settings);

    _validateData(data);

    final mediaPaths = <String>{};
    final mediaFiles = _validateMedia(
      data,
      files,
      mediaPaths: mediaPaths,
      retainMediaBytes: retainMediaBytes,
    );
    _verifyRestoreEntries(
      files,
      expectedEntries,
      mediaFiles,
      mediaPaths: mediaPaths,
      closeArchiveEntries: closeArchiveEntries,
    );

    return ValidatedBackup(
      manifest: manifest,
      data: data,
      settings: settings,
      mediaFiles: mediaFiles,
      mediaPaths: mediaPaths,
      mediaReader: retainMediaBytes || closeArchiveEntries
          ? null
          : (path) {
              final entry = files[path];
              if (entry == null) return null;
              try {
                return entry.readBytes();
              } finally {
                entry.closeSync();
              }
            },
      disposer: onDispose,
      hasLegacyTimestamps: hasLegacyTimestamps,
    );
  }

  void _verifyRestoreEntries(
    Map<String, ArchiveFile> files,
    Map<String, (int, int)> expectedEntries,
    Map<String, Uint8List> mediaFiles, {
    required Set<String> mediaPaths,
    required bool closeArchiveEntries,
  }) {
    // Extra ZIP entries are ignored by the portable format. Do not expand
    // them merely to check a checksum: an unused entry could be very large.
    final paths = <String>{
      BackupFormat.manifestFileName,
      BackupFormat.dataFileName,
      BackupFormat.settingsFileName,
      ...mediaPaths,
    };
    for (final path in paths) {
      final file = files[path]!;
      try {
        final expected = expectedEntries[path];
        if (expected == null) {
          throw const FormatException('ZIP entry is missing from directory.');
        }
        final (expectedLength, expectedCrc) = expected;
        final bytes = mediaFiles[path] ?? file.readBytes();
        if (bytes == null ||
            bytes.length != expectedLength ||
            getCrc32(bytes) != expectedCrc) {
          throw const FormatException('ZIP entry size or CRC mismatch.');
        }
      } catch (error) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidArchive,
          message: 'Backup contains a damaged archive entry: $path',
          cause: error,
        );
      } finally {
        // The returned media map owns its byte arrays; the ZIP entry no
        // longer needs to retain an additional decompressed copy. File-backed
        // entries share one file handle, which the caller closes at the end.
        if (closeArchiveEntries) file.closeSync();
      }
    }
  }

  ArchiveFile _requiredFile(Map<String, ArchiveFile> files, String fileName) {
    final file = files[fileName];

    if (file == null) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.missingRequiredFile,
        message: 'Required backup file is missing: $fileName',
      );
    }

    return file;
  }

  Map<String, dynamic> _decodeJsonObject(ArchiveFile file, String fileName) {
    try {
      final bytes = file.readBytes();

      if (bytes == null) {
        throw const FormatException('Archive entry has no data.');
      }

      final text = utf8.decode(bytes, allowMalformed: false);

      final decoded = jsonDecode(text);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('JSON root must be an object.');
      }

      return decoded;
    } catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidJson,
        message: 'Invalid JSON in $fileName.',
        cause: error,
      );
    }
  }

  BackupManifest _parseManifest(Map<String, dynamic> json) {
    try {
      return BackupManifest.fromJson(json);
    } catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidManifest,
        message: 'Backup manifest has an invalid structure.',
        cause: error,
      );
    }
  }

  BackupData _parseData(Map<String, dynamic> json) {
    try {
      return BackupData.fromJson(json);
    } catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidData,
        message: 'Backup domain data has an invalid structure.',
        cause: error,
      );
    }
  }

  BackupSettings _parseSettings(Map<String, dynamic> json) {
    try {
      return BackupSettings.fromJson(json);
    } catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidSettings,
        message: 'Backup settings have an invalid structure.',
        cause: error,
      );
    }
  }

  void _validateManifest(BackupManifest manifest) {
    if (!BackupFormat.isSupportedVersion(manifest.backupFormatVersion)) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.unsupportedBackupFormat,
        message:
            'Unsupported backup format version: '
            '${manifest.backupFormatVersion}. '
            'Supported versions: '
            '${BackupFormat.minimumSupportedVersion}-'
            '${BackupFormat.currentVersion}.',
      );
    }

    if (manifest.appVersion.trim().isEmpty) {
      throw const BackupValidationException(
        code: BackupValidationErrorCode.invalidManifest,
        message: 'Backup app version must not be empty.',
      );
    }

    if (manifest.databaseSchemaVersion < 1) {
      throw const BackupValidationException(
        code: BackupValidationErrorCode.invalidManifest,
        message: 'Database schema version must be greater than zero.',
      );
    }
  }

  void _validateSettings(BackupSettings settings) {
    if (!const {'personal', 'collectionOnly'}.contains(settings.scope) ||
        !const {'system', 'light', 'dark'}.contains(settings.themeMode) ||
        !const {
          'green',
          'blue',
          'teal',
          'orange',
          'purple',
          'red',
        }.contains(settings.accent) ||
        !const {'system', 'english', 'german'}.contains(settings.language) ||
        !const {
          'commonNameFirst',
          'latinNameFirst',
        }.contains(settings.animalNameOrder) ||
        !const {
          'createdOldestFirst',
          'createdNewestFirst',
          'displayNameAscending',
          'displayNameDescending',
          'ageOldestFirst',
          'ageYoungestFirst',
          'latestFeedingNewestFirst',
          'latestFeedingOldestFirst',
          'categoryAscending',
          'categoryDescending',
        }.contains(settings.animalSortOrder) ||
        !const {
          'labelAscending',
          'labelDescending',
          'createdOldestFirst',
          'createdNewestFirst',
          'nameAscending',
          'nameDescending',
          'volumeAscending',
          'volumeDescending',
        }.contains(settings.boxSortOrder)) {
      throw const BackupValidationException(
        code: BackupValidationErrorCode.invalidSettings,
        message: 'Backup contains unsupported application settings.',
      );
    }
  }

  void _validateData(BackupData data) {
    final boxIds = <int>{};
    final archivedBoxIds = <int>{};
    final qrIds = <String>{};

    for (final box in data.boxes) {
      if (box.id <= 0) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidData,
          message:
              'Box ID must be greater than zero: '
              '${box.id}',
        );
      }

      if (!boxIds.add(box.id)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.duplicateRecordId,
          message: 'Duplicate Box ID: ${box.id}',
        );
      }

      if (!qrIds.add(box.qrId)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.duplicateQrId,
          message: 'Duplicate Box QR ID: ${box.qrId}',
        );
      }

      if (!qrIdValidator(box.qrId)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidQrId,
          message:
              'Invalid TerraManager Box QR ID: '
              '${box.qrId}',
        );
      }

      _validateBoxLifecycle(box);
      if (box.status == 'archived') {
        archivedBoxIds.add(box.id);
      }

      _validateOptionalPositiveDimension(
        value: box.widthCm,
        boxId: box.id,
        fieldName: 'widthCm',
      );

      _validateOptionalPositiveDimension(
        value: box.heightCm,
        boxId: box.id,
        fieldName: 'heightCm',
      );

      _validateOptionalPositiveDimension(
        value: box.depthCm,
        boxId: box.id,
        fieldName: 'depthCm',
      );
    }

    final animalIds = <int>{};
    final weightEntryIds = <int>{};

    for (final animal in data.animals) {
      if (animal.id <= 0) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidData,
          message:
              'Animal ID must be greater than zero: '
              '${animal.id}',
        );
      }

      if (!animalIds.add(animal.id)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.duplicateRecordId,
          message: 'Duplicate Animal ID: ${animal.id}',
        );
      }

      _validateAnimalEnums(animal);
      _validateAnimalEnvironment(animal);

      _validateAnimalLifecycle(animal, boxIds);
      if (animal.status == 'active' && archivedBoxIds.contains(animal.boxId)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidLifecycle,
          message:
              'Active Animal ${animal.id} references archived Box ${animal.boxId}.',
        );
      }

      _validateFeedingReminder(animal);

      for (final entry in animal.weightHistory) {
        if (entry.id <= 0 ||
            !entry.weightGrams.isFinite ||
            entry.weightGrams <= 0) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.invalidData,
            message: 'Animal ${animal.id} contains an invalid weight entry.',
          );
        }
        if (!weightEntryIds.add(entry.id)) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.duplicateRecordId,
            message: 'Duplicate AnimalWeightEntry ID: ${entry.id}',
          );
        }
      }
    }

    final feedingIds = <int>{};

    for (final feeding in data.feedingEvents) {
      if (feeding.id <= 0) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidData,
          message:
              'FeedingEvent ID must be greater than zero: '
              '${feeding.id}',
        );
      }

      if (!feedingIds.add(feeding.id)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.duplicateRecordId,
          message:
              'Duplicate FeedingEvent ID: '
              '${feeding.id}',
        );
      }

      if (!animalIds.contains(feeding.animalId)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.brokenRelationship,
          message:
              'FeedingEvent ${feeding.id} references '
              'missing Animal ${feeding.animalId}.',
        );
      }
    }
  }

  void _validateBoxLifecycle(BackupBox box) {
    try {
      BackupEnumCodec.decodeBoxStatus(box.status);
      if (box.archiveReason != null) {
        BackupEnumCodec.decodeBoxArchiveReason(box.archiveReason!);
      }
    } on FormatException catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidEnum,
        message: 'Box ${box.id} contains an unsupported enum value.',
        cause: error,
      );
    }

    if (box.status == 'active' &&
        (box.archiveReason != null ||
            box.archivedAt != null ||
            box.archiveNotes != null)) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidLifecycle,
        message: 'Active Box ${box.id} contains archive metadata.',
      );
    }

    if (box.status == 'archived' &&
        (box.archiveReason == null || box.archivedAt == null)) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidLifecycle,
        message:
            'Archived Box ${box.id} requires an archive reason and timestamp.',
      );
    }
  }

  void _validateOptionalPositiveDimension({
    required double? value,
    required int boxId,
    required String fieldName,
  }) {
    if (value == null) {
      return;
    }

    if (value <= 0) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidData,
        message:
            'Box $boxId contains invalid '
            '$fieldName: $value',
      );
    }
  }

  void _validateAnimalEnums(BackupAnimal animal) {
    try {
      BackupEnumCodec.decodeAnimalStatus(animal.status);

      final category = BackupEnumCodec.decodeAnimalCategory(animal.category);
      final subcategory = animal.subcategory == null
          ? null
          : BackupEnumCodec.decodeAnimalSubcategory(animal.subcategory!);
      if (!category.supports(subcategory)) {
        throw FormatException(
          'Subcategory ${animal.subcategory} does not belong to '
          '${animal.category}.',
        );
      }

      if (animal.sex != null) {
        BackupEnumCodec.decodeSex(animal.sex!);
      }

      if (animal.birthDateAccuracy != null) {
        BackupEnumCodec.decodeBirthDateAccuracy(animal.birthDateAccuracy!);
      }

      if (animal.archiveReason != null) {
        BackupEnumCodec.decodeArchiveReason(animal.archiveReason!);
      }
    } on FormatException catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidEnum,
        message:
            'Animal ${animal.id} contains '
            'an unsupported enum value.',
        cause: error,
      );
    }
  }

  void _validateAnimalEnvironment(BackupAnimal animal) {
    try {
      AnimalEnvironmentalLimits.validate(
        temperatureMinimum: animal.tempMin,
        temperatureMaximum: animal.tempMax,
        nighttimeTemperature: animal.nighttimeTemperature,
        nighttimeTemperatureMinimum: animal.nighttimeTemperatureMin,
        nighttimeTemperatureMaximum: animal.nighttimeTemperatureMax,
        humidityMinimum: animal.humidityMin,
        humidityMaximum: animal.humidityMax,
      );
    } on ArgumentError catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidData,
        message: 'Animal ${animal.id} contains invalid environmental values.',
        cause: error,
      );
    }
  }

  void _validateFeedingReminder(BackupAnimal animal) {
    try {
      FeedingWeekdaySchedule.validate(
        intervalDays: animal.feedingReminderIntervalDays,
        baseline: animal.feedingReminderBaseline,
        weekdays: animal.feedingReminderWeekdays,
        minuteOfDay: animal.feedingReminderMinuteOfDay,
        timeZone: animal.feedingReminderTimeZone,
      );
    } on ArgumentError {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidData,
        message:
            'Animal ${animal.id} contains an invalid '
            'feeding reminder configuration.',
      );
    }
  }

  void _validateAnimalLifecycle(BackupAnimal animal, Set<int> boxIds) {
    switch (animal.status) {
      case 'active':
        final boxId = animal.boxId;

        if (boxId == null) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.invalidLifecycle,
            message:
                'Active Animal ${animal.id} '
                'has no Box assignment.',
          );
        }

        if (!boxIds.contains(boxId)) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.brokenRelationship,
            message:
                'Active Animal ${animal.id} '
                'references missing Box $boxId.',
          );
        }

        if (animal.archiveReason != null ||
            animal.archivedAt != null ||
            animal.archiveNotes != null) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.invalidLifecycle,
            message:
                'Active Animal ${animal.id} '
                'contains archive metadata.',
          );
        }

        break;

      case 'archived':
        if (animal.boxId != null) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.invalidLifecycle,
            message:
                'Archived Animal ${animal.id} '
                'must not have a Box assignment.',
          );
        }

        if (animal.archiveReason == null) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.invalidLifecycle,
            message:
                'Archived Animal ${animal.id} '
                'has no archive reason.',
          );
        }

        if (animal.archivedAt == null) {
          throw BackupValidationException(
            code: BackupValidationErrorCode.invalidLifecycle,
            message:
                'Archived Animal ${animal.id} '
                'has no archive timestamp.',
          );
        }

        break;

      default:
        // The enum validation above already rejects this.
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidEnum,
          message:
              'Animal ${animal.id} has unsupported '
              'status ${animal.status}.',
        );
    }
  }

  Map<String, Uint8List> _validateMedia(
    BackupData data,
    Map<String, ArchiveFile> archiveFiles, {
    required Set<String> mediaPaths,
    required bool retainMediaBytes,
  }) {
    final result = <String, Uint8List>{};

    for (final box in data.boxes) {
      _validateEntityMedia(
        entityLabel: 'Box',
        entityId: box.id,
        primaryPath: box.pictureMediaPath,
        pictures: box.pictures,
        isValidPath: _isValidBoxMediaPath,
        archiveFiles: archiveFiles,
        result: result,
        mediaPaths: mediaPaths,
        retainMediaBytes: retainMediaBytes,
      );
    }

    for (final animal in data.animals) {
      _validateEntityMedia(
        entityLabel: 'Animal',
        entityId: animal.id,
        primaryPath: animal.pictureMediaPath,
        pictures: animal.pictures,
        isValidPath: _isValidAnimalMediaPath,
        archiveFiles: archiveFiles,
        result: result,
        mediaPaths: mediaPaths,
        retainMediaBytes: retainMediaBytes,
      );
    }

    return result;
  }

  void _validateEntityMedia({
    required String entityLabel,
    required int entityId,
    required String? primaryPath,
    required List<BackupPicture> pictures,
    required bool Function(String path) isValidPath,
    required Map<String, ArchiveFile> archiveFiles,
    required Map<String, Uint8List> result,
    required Set<String> mediaPaths,
    required bool retainMediaBytes,
  }) {
    final paths = pictures.map((picture) => picture.mediaPath).toList();
    if (paths.isEmpty && primaryPath != null) {
      paths.add(primaryPath);
    }
    if (primaryPath != null && !paths.contains(primaryPath)) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidMediaReference,
        message:
            '$entityLabel $entityId primary picture is not part of its gallery.',
      );
    }

    final uniquePaths = <String>{};
    for (final mediaPath in paths) {
      if (!uniquePaths.add(mediaPath)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidMediaReference,
          message:
              '$entityLabel $entityId contains a duplicate gallery '
              'media reference: $mediaPath',
        );
      }
      if (!isValidPath(mediaPath)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidMediaReference,
          message:
              '$entityLabel $entityId contains invalid media '
              'reference: $mediaPath',
        );
      }
      final file = archiveFiles[mediaPath];
      if (file == null) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.missingMedia,
          message: 'Referenced media file is missing: $mediaPath',
        );
      }
      final Uint8List? bytes;
      try {
        bytes = file.readBytes();
      } catch (error) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidArchive,
          message: 'Referenced media file is damaged: $mediaPath',
          cause: error,
        );
      }
      if (bytes == null || bytes.isEmpty) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.emptyMedia,
          message: 'Referenced media file is empty: $mediaPath',
        );
      }
      mediaPaths.add(mediaPath);
      if (!retainMediaBytes) {
        file.closeSync();
        continue;
      }
      // For compressed entries this is already an independent decoded
      // buffer. Stored entries can be views into the entire ZIP, so detach
      // those to avoid retaining the whole input through one picture.
      result[mediaPath] = bytes.buffer.lengthInBytes == bytes.lengthInBytes
          ? bytes
          : Uint8List.fromList(bytes);
    }
  }

  bool _isValidAnimalMediaPath(String path) {
    return path.startsWith('${BackupFormat.animalMediaDirectory}/') &&
        _isSafeArchivePath(path);
  }

  bool _isValidBoxMediaPath(String path) {
    return path.startsWith('${BackupFormat.boxMediaDirectory}/') &&
        _isSafeArchivePath(path);
  }

  bool _isSafeArchivePath(String path) {
    if (path.isEmpty) {
      return false;
    }

    if (path.startsWith('/') || path.startsWith('\\')) {
      return false;
    }

    // ZIP paths are portable forward-slash paths.
    if (path.contains('\\')) {
      return false;
    }

    if (path.contains(':')) {
      return false;
    }

    final segments = path.split('/');

    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      return false;
    }

    return true;
  }
}
