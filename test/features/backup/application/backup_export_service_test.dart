import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_exception.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/domain/backup_data.dart';
import 'package:terramanager/features/backup/domain/backup_format.dart';
import 'package:terramanager/features/backup/domain/backup_manifest.dart';
import 'package:terramanager/features/backup/domain/backup_settings.dart';
import 'package:terramanager/features/settings/app_accent.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('exports complete backup archive', () async {
    final boxId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
            createdAt: drift.Value(DateTime(2026, 8, 1, 10)),
            updatedAt: drift.Value(DateTime(2026, 8, 2, 12)),
          ),
        );

    final pictureBytes = Uint8List.fromList([1, 2, 3, 4]);

    final pictureMediaId = await MediaRepository(database).createMedia(
      fileName: 'animal.png',
      mimeType: 'image/png',
      data: pictureBytes,
    );

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      sex: Sex.female,
      birthDate: DateTime(2024, 1, 1),
      birthDateAccuracy: BirthDateAccuracy.yearKnown,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      pictureMediaId: pictureMediaId,
      notes: 'Test animal',
    );

    await FeedingRepository(database)
        .addFeeding(animalId, DateTime(2026, 8, 20, 18, 30), notes: 'Mouse');

    final service = BackupExportService(
      database,
      mediaReader: (_) async {
        fail(
          'Legacy media reader must not '
          'be used for persistent '
          'MediaAssets.',
        );
      },
    );

    final result = await service.createBackup(
      appVersion: '0.6.0',
      themeMode: ThemeMode.dark,
      accent: AppAccent.purple,
      createdAt: DateTime(2026, 9, 2, 15, 30),
    );

    expect(
      result.fileName,
      'TerraManager_Backup_'
      '2026-09-02_15-30.tmbackup',
    );

    expect(result.manifest.backupFormatVersion, 1);

    expect(result.manifest.databaseSchemaVersion, database.schemaVersion);

    expect(result.manifest.appVersion, '0.6.0');

    expect(result.settings.themeMode, 'dark');

    expect(result.settings.accent, 'purple');

    expect(result.data.boxes.length, 1);

    expect(result.data.animals.length, 1);

    expect(result.data.feedingEvents.length, 1);

    expect(result.mediaFileCount, 1);

    final archive = ZipDecoder().decodeBytes(result.bytes, verify: true);

    final manifestFile = archive.find(BackupFormat.manifestFileName);

    final dataFile = archive.find(BackupFormat.dataFileName);

    final settingsFile = archive.find(BackupFormat.settingsFileName);

    final pictureFile = archive.find('media/animals/$animalId.png');

    expect(manifestFile, isNotNull);

    expect(dataFile, isNotNull);

    expect(settingsFile, isNotNull);

    expect(pictureFile, isNotNull);

    expect(pictureFile!.readBytes(), pictureBytes);

    final dataJson =
        jsonDecode(utf8.decode(dataFile!.readBytes()!)) as Map<String, dynamic>;

    final animals = dataJson['animals'] as List<dynamic>;

    final animal = animals.single as Map<String, dynamic>;

    expect(animal['id'], animalId);

    expect(animal['boxId'], boxId);

    expect(animal['status'], 'active');

    expect(animal['sex'], 'female');

    expect(animal['birthDateAccuracy'], 'yearKnown');

    expect(animal['pictureMediaPath'], 'media/animals/$animalId.png');

    final feedingEvents = dataJson['feedingEvents'] as List<dynamic>;

    final feeding = feedingEvents.single as Map<String, dynamic>;

    expect(feeding['animalId'], animalId);

    expect(feeding['notes'], 'Mouse');
  });

  test('exports archived animal lifecycle data', () async {
    final boxId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:22222222-2222-4222-8222-222222222222',
          ),
        );

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Archived Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    await AnimalRepository(database).archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.rehomed,
      archivedAt: DateTime(2026, 9, 1),
      archiveNotes: 'New keeper',
    );

    final service = BackupExportService(database);

    final result = await service.createBackup(
      appVersion: '0.6.0',
      themeMode: ThemeMode.system,
      accent: AppAccent.green,
    );

    final animal = result.data.animals.single;

    expect(animal.status, 'archived');

    expect(animal.boxId, isNull);

    expect(animal.archiveReason, 'rehomed');

    expect(animal.archivedAt, DateTime(2026, 9, 1));

    expect(animal.archiveNotes, 'New keeper');
  });

  test('exports empty database', () async {
    final service = BackupExportService(database);

    final result = await service.createBackup(
      appVersion: '0.6.0',
      themeMode: ThemeMode.system,
      accent: AppAccent.green,
    );

    expect(result.data.boxes, isEmpty);

    expect(result.data.animals, isEmpty);

    expect(result.data.feedingEvents, isEmpty);

    expect(result.mediaFileCount, 0);

    final archive = ZipDecoder().decodeBytes(result.bytes, verify: true);

    expect(archive.find(BackupFormat.manifestFileName), isNotNull);

    expect(archive.find(BackupFormat.dataFileName), isNotNull);

    expect(archive.find(BackupFormat.settingsFileName), isNotNull);
  });

  test(
    'fails instead of silently omitting unreadable legacy picture',
    () async {
      final boxId = await database
          .into(database.boxes)
          .insert(
            BoxesCompanion.insert(
              qrId: 'TM:BOX:33333333-3333-4333-8333-333333333333',
            ),
          );

      await AnimalRepository(database).createAnimal(
        boxId: boxId,
        commonName: 'Test Animal',
        latinName: 'Test species',
        tempMin: 20,
        tempMax: 25,
        humidityMin: 40,
        humidityMax: 70,
        picturePath: 'missing/image.jpg',
      );

      final service = BackupExportService(
        database,
        mediaReader: (_) async {
          throw Exception('File not found');
        },
      );

      expect(
        () => service.createBackup(
          appVersion: '0.6.0',
          themeMode: ThemeMode.system,
          accent: AppAccent.green,
        ),
        throwsA(isA<BackupExportException>()),
      );
    },
  );

  test('exports readable legacy picture as fallback', () async {
    final boxId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:77777777-7777-4777-8777-777777777777',
          ),
        );

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Legacy Animal',
      latinName: 'Legacy species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      picturePath: 'legacy/image.jpg',
    );

    final pictureBytes = Uint8List.fromList([9, 8, 7]);

    final service = BackupExportService(
      database,
      mediaReader: (path) async {
        expect(path, 'legacy/image.jpg');

        return pictureBytes;
      },
    );

    final result = await service.createBackup(
      appVersion: '0.6.0',
      themeMode: ThemeMode.system,
      accent: AppAccent.green,
    );

    expect(
      result.data.animals.single.pictureMediaPath,
      'media/animals/$animalId.jpg',
    );

    expect(result.mediaFileCount, 1);

    final archive = ZipDecoder().decodeBytes(result.bytes, verify: true);

    final mediaFile = archive.find(
      'media/animals/'
      '$animalId.jpg',
    );

    expect(mediaFile, isNotNull);

    expect(mediaFile!.readBytes(), pictureBytes);
  });

  test('generated archive can be decoded back into backup models', () async {
    final boxId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:44444444-4444-4444-8444-444444444444',
          ),
        );

    final pictureBytes = Uint8List.fromList([10, 20, 30, 40, 50]);

    final pictureMediaId = await MediaRepository(database).createMedia(
      fileName: 'roundtrip.jpg',
      mimeType: 'image/jpeg',
      data: pictureBytes,
    );

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Roundtrip Snake',
      latinName: 'Pantherophis guttatus',
      sex: Sex.male,
      birthDate: DateTime(2024, 5, 1),
      birthDateAccuracy: BirthDateAccuracy.monthKnown,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      pictureMediaId: pictureMediaId,
      notes: 'Roundtrip animal',
    );

    await FeedingRepository(database).addFeeding(
      animalId,
      DateTime(2026, 9, 2, 14, 15),
      notes: 'Roundtrip feeding',
    );

    final service = BackupExportService(database);

    final result = await service.createBackup(
      appVersion: '0.6.0',
      themeMode: ThemeMode.dark,
      accent: AppAccent.teal,
      createdAt: DateTime.utc(2026, 9, 2, 16),
    );

    final archive = ZipDecoder().decodeBytes(result.bytes, verify: true);

    final manifestFile = archive.find(BackupFormat.manifestFileName);

    final dataFile = archive.find(BackupFormat.dataFileName);

    final settingsFile = archive.find(BackupFormat.settingsFileName);

    final mediaFile = archive.find('media/animals/$animalId.jpg');

    expect(manifestFile, isNotNull);

    expect(dataFile, isNotNull);

    expect(settingsFile, isNotNull);

    expect(mediaFile, isNotNull);

    final manifestJson = jsonDecode(
      utf8.decode(manifestFile!.readBytes()!),
    ) as Map<String, dynamic>;

    final dataJson =
        jsonDecode(utf8.decode(dataFile!.readBytes()!)) as Map<String, dynamic>;

    final settingsJson = jsonDecode(
      utf8.decode(settingsFile!.readBytes()!),
    ) as Map<String, dynamic>;

    final restoredManifest = BackupManifest.fromJson(manifestJson);

    final restoredData = BackupData.fromJson(dataJson);

    final restoredSettings = BackupSettings.fromJson(settingsJson);

    expect(restoredManifest.backupFormatVersion, 1);

    expect(restoredManifest.appVersion, '0.6.0');

    expect(restoredManifest.databaseSchemaVersion, database.schemaVersion);

    expect(restoredManifest.createdAt, DateTime.utc(2026, 9, 2, 16));

    expect(restoredData.boxes.length, 1);

    expect(restoredData.animals.length, 1);

    expect(restoredData.feedingEvents.length, 1);

    final restoredBox = restoredData.boxes.single;

    expect(restoredBox.id, boxId);

    expect(restoredBox.qrId, 'TM:BOX:44444444-4444-4444-8444-444444444444');

    final restoredAnimal = restoredData.animals.single;

    expect(restoredAnimal.id, animalId);

    expect(restoredAnimal.boxId, boxId);

    expect(restoredAnimal.status, 'active');

    expect(restoredAnimal.sex, 'male');

    expect(restoredAnimal.birthDateAccuracy, 'monthKnown');

    expect(restoredAnimal.pictureMediaPath, 'media/animals/$animalId.jpg');

    expect(restoredAnimal.notes, 'Roundtrip animal');

    final restoredFeeding = restoredData.feedingEvents.single;

    expect(restoredFeeding.animalId, animalId);

    expect(restoredFeeding.fedAt, DateTime(2026, 9, 2, 14, 15));

    expect(restoredFeeding.notes, 'Roundtrip feeding');

    expect(restoredSettings.themeMode, 'dark');

    expect(restoredSettings.accent, 'teal');

    expect(mediaFile!.readBytes(), pictureBytes);
  });
}
