import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/animal_repository.dart';
import '../../../core/database/repositories/animal_weight_repository.dart';
import '../../../core/database/repositories/box_repository.dart';
import '../../../core/database/repositories/feeding_repository.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/database/repositories/picture_gallery_repository.dart';
import '../../settings/app_accent.dart';
import '../../settings/app_language.dart';
import '../../settings/animal_name_order.dart';
import '../../settings/animal_sort_order.dart';
import '../../settings/box_sort_order.dart';
import '../domain/backup_data.dart';
import '../domain/backup_enum_codec.dart';
import '../domain/backup_format.dart';
import '../domain/backup_manifest.dart';
import '../domain/backup_media_format.dart';
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
    AnimalNameOrder animalNameOrder = AnimalNameOrder.commonNameFirst,
    AnimalSortOrder animalSortOrder = AnimalSortOrder.createdOldestFirst,
    bool animalCategoryViewEnabled = false,
    bool bigPictureModeEnabled = false,
    BoxSortOrder boxSortOrder = BoxSortOrder.labelAscending,
    DateTime? createdAt,
  }) async {
    final backupTime = createdAt ?? DateTime.now();

    final boxes = await BoxRepository(database).getAllBoxes();

    final animals = await AnimalRepository(database).getAllAnimals();

    final feedingEvents = await FeedingRepository(database).getAllFeedings();

    final mediaRepository = MediaRepository(database);
    final galleryRepository = PictureGalleryRepository(database);

    final mediaFiles = <String, Uint8List>{};

    final backupBoxes = <BackupBox>[];

    for (final box in boxes) {
      final exportedPictures = await _exportBoxPictures(
        box: box,
        mediaRepository: mediaRepository,
        galleryRepository: galleryRepository,
        mediaFiles: mediaFiles,
      );

      backupBoxes.add(
        BackupBox(
          id: box.id,
          qrId: box.qrId,
          status: BackupEnumCodec.encodeBoxStatus(box.status),
          archiveReason: box.archiveReason == null
              ? null
              : BackupEnumCodec.encodeBoxArchiveReason(box.archiveReason!),
          archivedAt: box.archivedAt,
          archiveNotes: box.archiveNotes,
          name: box.name,
          widthCm: box.widthCm,
          heightCm: box.heightCm,
          depthCm: box.depthCm,
          temperatureZones: box.temperatureZones,
          notes: box.notes,
          pictureMediaPath: exportedPictures.primaryPath,
          pictures: exportedPictures.pictures,
          createdAt: box.createdAt,
          updatedAt: box.updatedAt,
        ),
      );
    }

    final backupAnimals = <BackupAnimal>[];

    for (final animal in animals) {
      final weightHistory = await AnimalWeightRepository(database)
          .getHistory(animal.id);
      final exportedPictures = await _exportAnimalPictures(
        animal: animal,
        mediaRepository: mediaRepository,
        galleryRepository: galleryRepository,
        mediaFiles: mediaFiles,
      );

      backupAnimals.add(
        BackupAnimal(
          id: animal.id,
          boxId: animal.boxId,
          status: BackupEnumCodec.encodeAnimalStatus(animal.status),
          commonName: animal.commonName,
          latinName: animal.latinName,
          category: BackupEnumCodec.encodeAnimalCategory(animal.category),
          subcategory: animal.subcategory == null
              ? null
              : BackupEnumCodec.encodeAnimalSubcategory(animal.subcategory!),
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
          nighttimeTemperature: animal.nighttimeTemperature,
          nighttimeTemperatureMin: animal.nighttimeTemperatureMin,
          nighttimeTemperatureMax: animal.nighttimeTemperatureMax,
          humidityMin: animal.humidityMin,
          humidityMax: animal.humidityMax,
          originHabitat: animal.originHabitat,
          weight: animal.weight,
          weightHistory: weightHistory
              .map(
                (entry) => BackupWeightEntry(
                  id: entry.id,
                  weightGrams: entry.weightGrams,
                  measuredAt: entry.measuredAt,
                ),
              )
              .toList(),
          sheddingNotes: animal.sheddingNotes,
          restOrDormancyPeriods: animal.restOrDormancyPeriods,
          temperatureZones: animal.temperatureZones,
          pictureMediaPath: exportedPictures.primaryPath,
          pictures: exportedPictures.pictures,
          notes: animal.notes,
          archiveReason: animal.archiveReason == null
              ? null
              : BackupEnumCodec.encodeArchiveReason(animal.archiveReason!),
          archivedAt: animal.archivedAt,
          archiveNotes: animal.archiveNotes,
          feedingReminderIntervalDays: animal.feedingReminderIntervalDays,
          feedingReminderBaseline: animal.feedingReminderBaseline,
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
      animalNameOrder: animalNameOrder,
      animalSortOrder: animalSortOrder,
      animalCategoryViewEnabled: animalCategoryViewEnabled,
      bigPictureModeEnabled: bigPictureModeEnabled,
      boxSortOrder: boxSortOrder,
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

  Future<_ExportedPictures> _exportBoxPictures({
    required Box box,
    required MediaRepository mediaRepository,
    required PictureGalleryRepository galleryRepository,
    required Map<String, Uint8List> mediaFiles,
  }) async {
    final gallery = await galleryRepository.getBoxPictures(box.id);
    if (gallery.isNotEmpty) {
      return _exportPersistentPictures(
        ownerLabel: 'box',
        ownerId: box.id,
        mediaDirectory: BackupFormat.boxMediaDirectory,
        primaryMediaId: box.pictureMediaId,
        pictures: gallery,
        mediaFiles: mediaFiles,
      );
    }

    return _exportSinglePersistentPicture(
      ownerLabel: 'box',
      ownerId: box.id,
      mediaDirectory: BackupFormat.boxMediaDirectory,
      mediaId: box.pictureMediaId,
      mediaRepository: mediaRepository,
      mediaFiles: mediaFiles,
    );
  }

  Future<_ExportedPictures> _exportAnimalPictures({
    required Animal animal,
    required MediaRepository mediaRepository,
    required PictureGalleryRepository galleryRepository,
    required Map<String, Uint8List> mediaFiles,
  }) async {
    final gallery = await galleryRepository.getAnimalPictures(animal.id);
    if (gallery.isNotEmpty) {
      return _exportPersistentPictures(
        ownerLabel: 'animal',
        ownerId: animal.id,
        mediaDirectory: BackupFormat.animalMediaDirectory,
        primaryMediaId: animal.pictureMediaId,
        pictures: gallery,
        mediaFiles: mediaFiles,
      );
    }

    if (animal.pictureMediaId != null) {
      return _exportSinglePersistentPicture(
        ownerLabel: 'animal',
        ownerId: animal.id,
        mediaDirectory: BackupFormat.animalMediaDirectory,
        mediaId: animal.pictureMediaId,
        mediaRepository: mediaRepository,
        mediaFiles: mediaFiles,
      );
    }

    // Legacy fallback for installations where
    // picturePath could not yet be migrated.
    final sourcePath = animal.picturePath?.trim();

    if (sourcePath == null || sourcePath.isEmpty) {
      return const _ExportedPictures(primaryPath: null, pictures: []);
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

    final extension = BackupMediaFormat.extensionForExport(source: sourcePath);

    final mediaPath =
        '${BackupFormat.animalMediaDirectory}/'
        '${animal.id}.$extension';

    mediaFiles[mediaPath] = bytes;

    return _ExportedPictures(
      primaryPath: mediaPath,
      pictures: [
        BackupPicture(mediaPath: mediaPath, capturedAt: animal.createdAt),
      ],
    );
  }

  Future<_ExportedPictures> _exportSinglePersistentPicture({
    required String ownerLabel,
    required int ownerId,
    required String mediaDirectory,
    required int? mediaId,
    required MediaRepository mediaRepository,
    required Map<String, Uint8List> mediaFiles,
  }) async {
    if (mediaId == null) {
      return const _ExportedPictures(primaryPath: null, pictures: []);
    }
    final media = await mediaRepository.getMediaById(mediaId);
    if (media == null) {
      throw BackupExportException(
        'Persistent picture for $ownerLabel $ownerId does not exist.',
      );
    }
    if (media.data.isEmpty) {
      throw BackupExportException(
        'Persistent picture for $ownerLabel $ownerId is empty.',
      );
    }
    final extension = BackupMediaFormat.extensionForExport(
      source: media.fileName,
      mimeType: media.mimeType,
    );
    final mediaPath = '$mediaDirectory/$ownerId.$extension';
    mediaFiles[mediaPath] = media.data;
    return _ExportedPictures(
      primaryPath: mediaPath,
      pictures: [
        BackupPicture(mediaPath: mediaPath, capturedAt: media.createdAt),
      ],
    );
  }

  _ExportedPictures _exportPersistentPictures({
    required String ownerLabel,
    required int ownerId,
    required String mediaDirectory,
    required int? primaryMediaId,
    required List<PictureGalleryEntry> pictures,
    required Map<String, Uint8List> mediaFiles,
  }) {
    final backupPictures = <BackupPicture>[];
    String? primaryPath;
    for (final picture in pictures) {
      if (picture.media.data.isEmpty) {
        throw BackupExportException(
          'Persistent picture ${picture.media.id} for '
          '$ownerLabel $ownerId is empty.',
        );
      }
      final extension = BackupMediaFormat.extensionForExport(
        source: picture.media.fileName,
        mimeType: picture.media.mimeType,
      );
      final isPrimary = picture.media.id == primaryMediaId;
      final fileStem = isPrimary
          ? '$ownerId'
          : '${ownerId}_gallery_${picture.sortOrder}_${picture.media.id}';
      final mediaPath = '$mediaDirectory/$fileStem.$extension';
      mediaFiles[mediaPath] = picture.media.data;
      backupPictures.add(
        BackupPicture(mediaPath: mediaPath, capturedAt: picture.capturedAt),
      );
      if (isPrimary) {
        primaryPath = mediaPath;
      }
    }
    return _ExportedPictures(
      primaryPath: primaryPath,
      pictures: backupPictures,
    );
  }

  static Future<Uint8List> _readLegacyMediaFromPath(String path) {
    return XFile(path).readAsBytes();
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

class _ExportedPictures {
  const _ExportedPictures({required this.primaryPath, required this.pictures});

  final String? primaryPath;
  final List<BackupPicture> pictures;
}
