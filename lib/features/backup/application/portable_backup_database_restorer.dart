import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/validation/animal_weight_parser.dart';
import '../domain/backup_enum_codec.dart';
import '../domain/backup_data.dart';
import '../domain/backup_media_format.dart';
import 'validated_backup.dart';

class PortableBackupDatabaseRestorer {
  final AppDatabase database;

  PortableBackupDatabaseRestorer(this.database);

  Future<int> restore(ValidatedBackup backup) {
    return database.transaction(() async {
      await database.delete(database.feedingEvents).go();

      await database.delete(database.animalWeightEntries).go();

      await database.delete(database.sheddingEvents).go();

      await database.delete(database.animalPictureAssociations).go();

      await database.delete(database.boxPictureAssociations).go();

      await database.delete(database.animals).go();

      await database.delete(database.boxes).go();

      await database.delete(database.mediaAssets).go();

      await database.customStatement(
        "DELETE FROM sqlite_sequence "
        "WHERE name IN ("
        "'boxes', "
        "'animals', "
        "'animal_weight_entries', "
        "'shedding_events', "
        "'feeding_events', "
        "'media_assets', "
        "'animal_picture_associations', "
        "'box_picture_associations'"
        ")",
      );

      var restoredMediaCount = 0;

      for (final box in backup.data.boxes) {
        final restoredPictures = await _restorePictures(
          backup: backup,
          pictures: box.pictures,
          primaryPath: box.pictureMediaPath,
          fallbackCapturedAt: box.createdAt,
          updatedAt: box.updatedAt,
        );
        restoredMediaCount += restoredPictures.items.length;

        await database
            .into(database.boxes)
            .insert(
              BoxesCompanion(
                id: Value(box.id),
                qrId: Value(box.qrId),
                status: Value(BackupEnumCodec.decodeBoxStatus(box.status)),
                archiveReason: Value(
                  box.archiveReason == null
                      ? null
                      : BackupEnumCodec.decodeBoxArchiveReason(
                          box.archiveReason!,
                        ),
                ),
                archivedAt: Value(box.archivedAt),
                archiveNotes: Value(box.archiveNotes),
                name: Value(box.name),
                widthCm: Value(box.widthCm),
                heightCm: Value(box.heightCm),
                depthCm: Value(box.depthCm),
                temperatureZones: Value(box.temperatureZones),
                notes: Value(box.notes),
                pictureMediaId: Value(restoredPictures.primaryMediaId),
                createdAt: Value(box.createdAt),
                updatedAt: Value(box.updatedAt),
              ),
            );

        for (final (index, item) in restoredPictures.items.indexed) {
          await database
              .into(database.boxPictureAssociations)
              .insert(
                BoxPictureAssociationsCompanion.insert(
                  boxId: box.id,
                  mediaAssetId: item.mediaId,
                  capturedAt: item.picture.capturedAt,
                  sortOrder: index,
                ),
              );
        }
      }

      for (final animal in backup.data.animals) {
        final status = BackupEnumCodec.decodeAnimalStatus(animal.status);

        final category = BackupEnumCodec.decodeAnimalCategory(animal.category);

        final subcategory = animal.subcategory == null
            ? null
            : BackupEnumCodec.decodeAnimalSubcategory(animal.subcategory!);

        final sex = animal.sex == null
            ? null
            : BackupEnumCodec.decodeSex(animal.sex!);

        final birthDateAccuracy = animal.birthDateAccuracy == null
            ? null
            : BackupEnumCodec.decodeBirthDateAccuracy(
                animal.birthDateAccuracy!,
              );

        final archiveReason = animal.archiveReason == null
            ? null
            : BackupEnumCodec.decodeArchiveReason(animal.archiveReason!);

        final restoredPictures = await _restorePictures(
          backup: backup,
          pictures: animal.pictures,
          primaryPath: animal.pictureMediaPath,
          fallbackCapturedAt: animal.createdAt,
          updatedAt: animal.updatedAt,
        );
        restoredMediaCount += restoredPictures.items.length;

        final parsedLegacyWeight = animal.weightHistory.isEmpty
            ? AnimalWeightParser.parseUnambiguousLegacyGrams(animal.weight)
            : null;
        final restoredWeightHistory = animal.weightHistory.isNotEmpty
            ? animal.weightHistory
            : parsedLegacyWeight == null
            ? const <BackupWeightEntry>[]
            : [
                BackupWeightEntry(
                  id: 0,
                  weightGrams: parsedLegacyWeight,
                  measuredAt: animal.updatedAt,
                ),
              ];
        final legacySheddingNotes = animal.sheddingNotes?.trim();

        final restoredSheddingHistory = animal.sheddingHistory.isNotEmpty
            ? animal.sheddingHistory
            : legacySheddingNotes == null || legacySheddingNotes.isEmpty
            ? const <BackupSheddingEvent>[]
            : [
                BackupSheddingEvent(
                  id: 0,
                  shedAt: animal.updatedAt,
                  notes: legacySheddingNotes,
                  createdAt: animal.updatedAt,
                  updatedAt: animal.updatedAt,
                ),
              ];
        await database
            .into(database.animals)
            .insert(
              AnimalsCompanion(
                id: Value(animal.id),
                boxId: Value(animal.boxId),
                status: Value(status),
                commonName: Value(animal.commonName),
                latinName: Value(animal.latinName),
                category: Value(category),
                subcategory: Value(subcategory),
                sex: Value(sex),
                birthDate: Value(animal.birthDate),
                birthDateAccuracy: Value(birthDateAccuracy),
                tempMin: Value(animal.tempMin),
                tempMax: Value(animal.tempMax),
                nighttimeTemperature: Value(animal.nighttimeTemperature),
                nighttimeTemperatureMin: Value(
                  animal.nighttimeTemperatureMin ?? animal.nighttimeTemperature,
                ),
                nighttimeTemperatureMax: Value(
                  animal.nighttimeTemperatureMax ?? animal.nighttimeTemperature,
                ),
                humidityMin: Value(animal.humidityMin),
                humidityMax: Value(animal.humidityMax),
                originHabitat: Value(animal.originHabitat),
                weight: Value(
                  parsedLegacyWeight == null ? animal.weight : null,
                ),
                sheddingNotes: const Value(null),
                restOrDormancyPeriods: Value(animal.restOrDormancyPeriods),
                temperatureZones: Value(animal.temperatureZones),
                picturePath: const Value(null),
                pictureMediaId: Value(restoredPictures.primaryMediaId),
                notes: Value(animal.notes),
                archiveReason: Value(archiveReason),
                archivedAt: Value(animal.archivedAt),
                archiveNotes: Value(animal.archiveNotes),
                feedingReminderIntervalDays: Value(
                  animal.feedingReminderIntervalDays,
                ),
                feedingReminderBaseline: Value(animal.feedingReminderBaseline),
                showWeightOnDetail: Value(animal.showWeightOnDetail),
                showSheddingOnDetail: Value(animal.showSheddingOnDetail),
                createdAt: Value(animal.createdAt),
                updatedAt: Value(animal.updatedAt),
              ),
            );

        for (final entry in restoredWeightHistory) {
          await database
              .into(database.animalWeightEntries)
              .insert(
                AnimalWeightEntriesCompanion.insert(
                  id: entry.id > 0 ? Value(entry.id) : const Value.absent(),
                  animalId: animal.id,
                  weightGrams: entry.weightGrams,
                  measuredAt: entry.measuredAt,
                ),
              );
        }
        for (final entry in restoredSheddingHistory) {
          await database
              .into(database.sheddingEvents)
              .insert(
                SheddingEventsCompanion(
                  id: entry.id > 0 ? Value(entry.id) : const Value.absent(),
                  animalId: Value(animal.id),
                  shedAt: Value(entry.shedAt),
                  notes: Value(entry.notes),
                  createdAt: Value(entry.createdAt),
                  updatedAt: Value(entry.updatedAt),
                ),
              );
        }
        for (final (index, item) in restoredPictures.items.indexed) {
          await database
              .into(database.animalPictureAssociations)
              .insert(
                AnimalPictureAssociationsCompanion.insert(
                  animalId: animal.id,
                  mediaAssetId: item.mediaId,
                  capturedAt: item.picture.capturedAt,
                  sortOrder: index,
                ),
              );
        }
      }

      await database.copyLegacyAnimalTemperatureZonesToBoxes();

      for (final feeding in backup.data.feedingEvents) {
        await database
            .into(database.feedingEvents)
            .insert(
              FeedingEventsCompanion(
                id: Value(feeding.id),
                animalId: Value(feeding.animalId),
                fedAt: Value(feeding.fedAt),
                notes: Value(feeding.notes),
              ),
            );
      }

      final foreignKeyErrors = await database
          .customSelect('PRAGMA foreign_key_check')
          .get();

      if (foreignKeyErrors.isNotEmpty) {
        throw StateError(
          'Foreign key violations '
          'after restore: '
          '${foreignKeyErrors.map((row) => row.data).toList()}',
        );
      }

      return restoredMediaCount;
    });
  }

  Future<_RestoredPictures> _restorePictures({
    required ValidatedBackup backup,
    required List<BackupPicture> pictures,
    required String? primaryPath,
    required DateTime fallbackCapturedAt,
    required DateTime updatedAt,
  }) async {
    final effectivePictures = pictures.isNotEmpty
        ? pictures
        : primaryPath == null
        ? const <BackupPicture>[]
        : [
            BackupPicture(
              mediaPath: primaryPath,
              capturedAt: fallbackCapturedAt,
            ),
          ];
    final restored = <_RestoredPicture>[];
    int? primaryMediaId;
    for (final picture in effectivePictures) {
      final bytes = backup.mediaFiles[picture.mediaPath];
      if (bytes == null) {
        throw StateError(
          'Validated backup is missing media: ${picture.mediaPath}',
        );
      }
      if (bytes.isEmpty) {
        throw StateError(
          'Validated backup contains empty media: ${picture.mediaPath}',
        );
      }
      final fileName = _fileNameFromPortablePath(picture.mediaPath);
      final mediaId = await database
          .into(database.mediaAssets)
          .insert(
            MediaAssetsCompanion.insert(
              fileName: fileName,
              mimeType: BackupMediaFormat.mimeTypeFromFileName(fileName),
              data: bytes,
              createdAt: Value(picture.capturedAt),
              updatedAt: Value(updatedAt),
            ),
          );
      restored.add(_RestoredPicture(mediaId: mediaId, picture: picture));
      if (picture.mediaPath == primaryPath) {
        primaryMediaId = mediaId;
      }
    }
    return _RestoredPictures(primaryMediaId: primaryMediaId, items: restored);
  }

  static String _fileNameFromPortablePath(String portablePath) {
    final normalized = portablePath.replaceAll('\\', '/');

    final fileName = normalized.split('/').last.trim();

    if (fileName.isEmpty) {
      throw StateError(
        'Invalid media path: '
        '$portablePath',
      );
    }

    return fileName;
  }
}

class _RestoredPictures {
  const _RestoredPictures({required this.primaryMediaId, required this.items});

  final int? primaryMediaId;
  final List<_RestoredPicture> items;
}

class _RestoredPicture {
  const _RestoredPicture({required this.mediaId, required this.picture});

  final int mediaId;
  final BackupPicture picture;
}
