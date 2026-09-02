import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/animal_repository.dart';
import '../../../core/database/repositories/box_repository.dart';
import '../../../core/database/repositories/feeding_repository.dart';
import '../../settings/app_accent.dart';
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
    : _mediaReader = mediaReader ?? _readMediaFromPath;

  Future<BackupExportResult> createBackup({
    required String appVersion,
    required ThemeMode themeMode,
    required AppAccent accent,
    DateTime? createdAt,
  }) async {
    final backupTime = createdAt ?? DateTime.now();

    final boxes = await BoxRepository(database).getAllBoxes();

    final animals = await AnimalRepository(database).getAllAnimals();

    final feedingEvents = await FeedingRepository(database).getAllFeedings();

    final mediaFiles = <String, Uint8List>{};

    final backupAnimals = <BackupAnimal>[];

    for (final animal in animals) {
      final pictureMediaPath = await _exportAnimalPicture(animal, mediaFiles);

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
      boxes: boxes
          .map(
            (box) => BackupBox(
              id: box.id,
              qrId: box.qrId,
              createdAt: box.createdAt,
              updatedAt: box.updatedAt,
            ),
          )
          .toList(),
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

  Future<String?> _exportAnimalPicture(
    Animal animal,
    Map<String, Uint8List> mediaFiles,
  ) async {
    final sourcePath = animal.picturePath?.trim();

    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    Uint8List bytes;

    try {
      bytes = await _mediaReader(sourcePath);
    } catch (error) {
      throw BackupExportException(
        'Failed to read picture for animal '
        '${animal.id}.',
        cause: error,
      );
    }

    if (bytes.isEmpty) {
      throw BackupExportException(
        'Picture for animal '
        '${animal.id} is empty.',
      );
    }

    final mediaPath =
        '${BackupFormat.animalMediaDirectory}/'
        '${animal.id}.${_mediaExtension(sourcePath)}';

    mediaFiles[mediaPath] = bytes;

    return mediaPath;
  }

  static Future<Uint8List> _readMediaFromPath(String path) {
    return XFile(path).readAsBytes();
  }

  static String _mediaExtension(String sourcePath) {
    final withoutQuery = sourcePath.split('?').first.split('#').first;

    final normalized = withoutQuery.replaceAll('\\', '/');

    final fileName = normalized.split('/').last;

    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'img';
    }

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

    if (!supportedExtensions.contains(extension)) {
      return 'img';
    }

    return extension;
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
