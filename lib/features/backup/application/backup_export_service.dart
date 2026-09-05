import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/animal_repository.dart';
import '../../../core/database/repositories/box_repository.dart';
import '../../../core/database/repositories/feeding_repository.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../settings/app_accent.dart';
import '../../settings/app_language.dart';
import '../domain/backup_data.dart';
import '../domain/backup_enum_codec.dart';
import '../domain/backup_format.dart';
import '../domain/backup_manifest.dart';
import 'backup_export_exception.dart';
import 'backup_export_result.dart';
import 'backup_settings_codec.dart';

typedef BackupMediaReader = Future<Uint8List> Function(String path);

class BackupExportService {
  final AppDatabase database;
  final BackupMediaReader _mediaReader;

  BackupExportService(this.database, {BackupMediaReader? mediaReader})
    : _mediaReader = mediaReader ?? _readLegacyMediaFromPath;

  Future<BackupExportResult> createBackup({
    required String appVersion,
    required ThemeMode themeMode,
    required AppAccent accent,
    AppLanguage language = AppLanguage.system,
    DateTime? createdAt,
  }) async {
    final backupTime = createdAt ?? DateTime.now();

    final boxes = await BoxRepository(database).getAllBoxes();

    final animals = await AnimalRepository(database).getAllAnimals();

    final feedingEvents = await FeedingRepository(database).getAllFeedings();

    final mediaRepository = MediaRepository(database);

    final mediaFiles = <String, Uint8List>{};

    final backupBoxes = <BackupBox>[];

    for (final box in boxes) {
      final pictureMediaPath = await _exportBoxPicture(
        box: box,
        mediaRepository: mediaRepository,
        mediaFiles: mediaFiles,
      );

      backupBoxes.add(
        BackupBox(
          id: box.id,
          qrId: box.qrId,
          widthCm: box.widthCm,
          heightCm: box.heightCm,
          depthCm: box.depthCm,
          pictureMediaPath: pictureMediaPath,
          createdAt: box.createdAt,
          updatedAt: box.updatedAt,
        ),
      );
    }

    final backupAnimals = <BackupAnimal>[];

    for (final animal in animals) {
      final pictureMediaPath = await _exportAnimalPicture(
        animal: animal,
        mediaRepository: mediaRepository,
        mediaFiles: mediaFiles,
      );

      backupAnimals.add(
        BackupAnimal(
          id: animal.id,
          boxId: animal.boxId,
          status: BackupEnumCodec.encodeAnimalStatus(animal.status),
          commonName: animal.commonName,
          latinName: animal.latinName,
          sex: animal.sex == null
              ? null
              : BackupEnumCodec.encodeSex(animal.sex!),
          birthDate: animal.birthDate,
          birthDateAccuracy: animal.birthDateAccuracy == null
              ? null
              : BackupEnumCodec.encodeBirthDateAccuracy(
                  animal.birthDateAccuracy!,
                ),
          tempMin: animal.tempMin,
          tempMax: animal.tempMax,
          humidityMin: animal.humidityMin,
          humidityMax: animal.humidityMax,
          pictureMediaPath: pictureMediaPath,
          notes: animal.notes,
          archiveReason: animal.archiveReason == null
              ? null
              : BackupEnumCodec.encodeArchiveReason(animal.archiveReason!),
          archivedAt: animal.archivedAt,
          archiveNotes: animal.archiveNotes,
          createdAt: animal.createdAt,
          updatedAt: animal.updatedAt,
        ),
      );
    }

    final backupData = BackupData(
      boxes: backupBoxes,
      animals: backupAnimals,
      feedingEvents: feedingEvents
          .map(
            (feeding) => BackupFeedingEvent(
              id: feeding.id,
              animalId: feeding.animalId,
              fedAt: feeding.fedAt,
              notes: feeding.notes,
            ),
          )
          .toList(),
    );

    final backupSettings = BackupSettingsCodec.encode(
      themeMode: themeMode,
      accent: accent,
      language: language,
    );

    final manifest = BackupManifest(
      backupFormatVersion: BackupFormat.currentVersion,
      appVersion: appVersion,
      databaseSchemaVersion: database.schemaVersion,
      createdAt: backupTime.toUtc(),
    );

    final archive = Archive();

    const jsonEncoder = JsonEncoder.withIndent('  ');

    archive.add(
      ArchiveFile.string(
        BackupFormat.manifestFileName,
        jsonEncoder.convert(manifest.toJson()),
      ),
    );

    archive.add(
      ArchiveFile.string(
        BackupFormat.dataFileName,
        jsonEncoder.convert(backupData.toJson()),
      ),
    );

    archive.add(
      ArchiveFile.string(
        BackupFormat.settingsFileName,
        jsonEncoder.convert(backupSettings.toJson()),
      ),
    );

    for (final entry in mediaFiles.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }

    final bytes = ZipEncoder().encodeBytes(archive);

    return BackupExportResult(
      bytes: bytes,
      fileName: _buildBackupFileName(backupTime),
      manifest: manifest,
      data: backupData,
      settings: backupSettings,
      mediaFileCount: mediaFiles.length,
    );
  }

  Future<String?> _exportBoxPicture({
    required Box box,
    required MediaRepository mediaRepository,
    required Map<String, Uint8List> mediaFiles,
  }) async {
    final mediaId = box.pictureMediaId;

    if (mediaId == null) {
      return null;
    }

    final media = await mediaRepository.getMediaById(mediaId);

    if (media == null) {
      throw BackupExportException(
        'Persistent picture for box '
        '${box.id} does not exist.',
      );
    }

    if (media.data.isEmpty) {
      throw BackupExportException(
        'Persistent picture for box '
        '${box.id} is empty.',
      );
    }

    final extension = _mediaExtension(media.fileName, mimeType: media.mimeType);

    final mediaPath =
        '${BackupFormat.boxMediaDirectory}/'
        '${box.id}.$extension';

    mediaFiles[mediaPath] = media.data;

    return mediaPath;
  }

  Future<String?> _exportAnimalPicture({
    required Animal animal,
    required MediaRepository mediaRepository,
    required Map<String, Uint8List> mediaFiles,
  }) async {
    final mediaId = animal.pictureMediaId;

    if (mediaId != null) {
      final media = await mediaRepository.getMediaById(mediaId);

      if (media == null) {
        throw BackupExportException(
          'Persistent picture for animal '
          '${animal.id} does not exist.',
        );
      }

      if (media.data.isEmpty) {
        throw BackupExportException(
          'Persistent picture for animal '
          '${animal.id} is empty.',
        );
      }

      final extension = _mediaExtension(
        media.fileName,
        mimeType: media.mimeType,
      );

      final mediaPath =
          '${BackupFormat.animalMediaDirectory}/'
          '${animal.id}.$extension';

      mediaFiles[mediaPath] = media.data;

      return mediaPath;
    }

    // Legacy fallback for installations where
    // picturePath could not yet be migrated.
    final sourcePath = animal.picturePath?.trim();

    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    Uint8List bytes;

    try {
      bytes = await _mediaReader(sourcePath);
    } catch (error) {
      throw BackupExportException(
        'Failed to read legacy picture '
        'for animal ${animal.id}.',
        cause: error,
      );
    }

    if (bytes.isEmpty) {
      throw BackupExportException(
        'Legacy picture for animal '
        '${animal.id} is empty.',
      );
    }

    final extension = _mediaExtension(sourcePath);

    final mediaPath =
        '${BackupFormat.animalMediaDirectory}/'
        '${animal.id}.$extension';

    mediaFiles[mediaPath] = bytes;

    return mediaPath;
  }

  static Future<Uint8List> _readLegacyMediaFromPath(String path) {
    return XFile(path).readAsBytes();
  }

  static String _mediaExtension(String source, {String? mimeType}) {
    final withoutQuery = source.split('?').first.split('#').first;

    final normalized = withoutQuery.replaceAll('\\', '/');

    final fileName = normalized.split('/').last;

    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex != -1 && dotIndex < fileName.length - 1) {
      final extension = fileName.substring(dotIndex + 1).toLowerCase();

      const supportedExtensions = {
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'bmp',
        'heic',
        'heif',
      };

      if (supportedExtensions.contains(extension)) {
        return extension;
      }
    }

    switch (mimeType?.trim().toLowerCase()) {
      case 'image/jpeg':
        return 'jpg';

      case 'image/png':
        return 'png';

      case 'image/webp':
        return 'webp';

      case 'image/gif':
        return 'gif';

      case 'image/bmp':
        return 'bmp';

      case 'image/heic':
        return 'heic';

      case 'image/heif':
        return 'heif';

      default:
        return 'img';
    }
  }

  static String _buildBackupFileName(DateTime dateTime) {
    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return 'TerraManager_Backup_'
        '${dateTime.year}-'
        '${twoDigits(dateTime.month)}-'
        '${twoDigits(dateTime.day)}_'
        '${twoDigits(dateTime.hour)}-'
        '${twoDigits(dateTime.minute)}.'
        '${BackupFormat.fileExtension}';
  }
}
