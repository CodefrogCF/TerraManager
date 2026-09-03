import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../domain/backup_data.dart';
import '../domain/backup_enum_codec.dart';
import '../domain/backup_format.dart';
import '../domain/backup_manifest.dart';
import '../domain/backup_settings.dart';
import 'backup_settings_codec.dart';
import 'backup_validation_exception.dart';
import 'validated_backup.dart';
import '../../../core/qr/qr_validator.dart';

typedef BackupQrIdValidator = bool Function(String qrId);

class BackupValidationService {
  final BackupQrIdValidator qrIdValidator;

  BackupValidationService({BackupQrIdValidator? qrIdValidator})
    : qrIdValidator = qrIdValidator ?? isValidBoxQrId;

  ValidatedBackup validate(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const BackupValidationException(
        code: BackupValidationErrorCode.invalidArchive,
        message: 'Backup file is empty.',
      );
    }

    final Archive archive;

    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
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

    final manifest = _parseManifest(manifestJson);

    _validateManifest(manifest);

    final data = _parseData(dataJson);

    final settings = _parseSettings(settingsJson);

    _validateSettings(settings);

    _validateData(data);

    final mediaFiles = _validateMedia(data, files);

    return ValidatedBackup(
      manifest: manifest,
      data: data,
      settings: settings,
      mediaFiles: mediaFiles,
    );
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
    try {
      BackupSettingsCodec.decodeThemeMode(settings.themeMode);

      BackupSettingsCodec.decodeAccent(settings.accent);
    } on FormatException catch (error) {
      throw BackupValidationException(
        code: BackupValidationErrorCode.invalidSettings,
        message: 'Backup contains unsupported appearance settings.',
        cause: error,
      );
    }
  }

  void _validateData(BackupData data) {
    final boxIds = <int>{};
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

      _validateAnimalLifecycle(animal, boxIds);
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
    Map<String, ArchiveFile> archiveFiles,
  ) {
    final result = <String, Uint8List>{};

    for (final box in data.boxes) {
      final mediaPath = box.pictureMediaPath;

      if (mediaPath == null) {
        continue;
      }

      if (!_isValidBoxMediaPath(mediaPath)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidMediaReference,
          message:
              'Box ${box.id} contains '
              'invalid media reference: $mediaPath',
        );
      }

      final file = archiveFiles[mediaPath];

      if (file == null) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.missingMedia,
          message:
              'Referenced media file is missing: '
              '$mediaPath',
        );
      }

      final bytes = file.readBytes();

      if (bytes == null || bytes.isEmpty) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.emptyMedia,
          message:
              'Referenced media file is empty: '
              '$mediaPath',
        );
      }

      result[mediaPath] = Uint8List.fromList(bytes);
    }

    for (final animal in data.animals) {
      final mediaPath = animal.pictureMediaPath;

      if (mediaPath == null) {
        continue;
      }

      if (!_isValidAnimalMediaPath(mediaPath)) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.invalidMediaReference,
          message:
              'Animal ${animal.id} contains '
              'invalid media reference: $mediaPath',
        );
      }

      final file = archiveFiles[mediaPath];

      if (file == null) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.missingMedia,
          message:
              'Referenced media file is missing: '
              '$mediaPath',
        );
      }

      final bytes = file.readBytes();

      if (bytes == null || bytes.isEmpty) {
        throw BackupValidationException(
          code: BackupValidationErrorCode.emptyMedia,
          message:
              'Referenced media file is empty: '
              '$mediaPath',
        );
      }

      result[mediaPath] = Uint8List.fromList(bytes);
    }

    return result;
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
