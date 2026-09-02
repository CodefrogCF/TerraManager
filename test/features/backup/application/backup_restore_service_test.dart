import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/features/backup/application/backup_restore_exception.dart';
import 'package:terramanager/features/backup/application/backup_restore_service.dart';
import 'package:terramanager/features/backup/application/validated_backup.dart';
import 'package:terramanager/features/backup/domain/backup_data.dart';
import 'package:terramanager/features/backup/domain/backup_manifest.dart';
import 'package:terramanager/features/backup/domain/backup_settings.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';

void main() {
  late AppDatabase database;
  late AppSettingsController settingsController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'light',
      'accent': 'red',
    });

    database = AppDatabase.test(NativeDatabase.memory());

    settingsController = AppSettingsController();

    await settingsController.load();
  });

  tearDown(() async {
    settingsController.dispose();
    await database.close();
  });

  Future<void> createExistingData() async {
    final boxId = await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
          ),
        );

    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Old Animal',
      latinName: 'Old species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
    );

    await FeedingRepository(database)
        .addFeeding(animalId, DateTime(2026, 8, 1), notes: 'Old feeding');
  }

  ValidatedBackup createTargetBackup({
    int animalBoxId = 5,
    bool includePicture = true,
  }) {
    const portablePicture = 'media/animals/12.jpg';

    return ValidatedBackup(
      manifest: BackupManifest(
        backupFormatVersion: 1,
        appVersion: '0.6.0',
        databaseSchemaVersion: 2,
        createdAt: DateTime.utc(2026, 9, 2),
      ),
      data: BackupData(
        boxes: [
          BackupBox(
            id: 5,
            qrId: 'TM:BOX:55555555-5555-4555-8555-555555555555',
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        ],
        animals: [
          BackupAnimal(
            id: 12,
            boxId: animalBoxId,
            status: 'active',
            commonName: 'Restored Animal',
            latinName: 'Restored species',
            sex: 'female',
            birthDate: null,
            birthDateAccuracy: null,
            tempMin: 24,
            tempMax: 28,
            humidityMin: 50,
            humidityMax: 70,
            pictureMediaPath: includePicture ? portablePicture : null,
            notes: 'Restored notes',
            archiveReason: null,
            archivedAt: null,
            archiveNotes: null,
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 2),
          ),
        ],
        feedingEvents: [
          BackupFeedingEvent(
            id: 30,
            animalId: 12,
            fedAt: DateTime(2026, 9, 2, 14, 30),
            notes: 'Restored feeding',
          ),
        ],
      ),
      settings: const BackupSettings(themeMode: 'dark', accent: 'teal'),
      mediaFiles: includePicture
          ? {
              portablePicture: Uint8List.fromList([1, 2, 3, 4]),
            }
          : {},
    );
  }

  test(
    'replaces database while preserving backup ids and relationships',
    () async {
      await createExistingData();

      var safetyBackupWritten = false;

      final service = BackupRestoreService(
        database: database,
        settingsController: settingsController,
        safetyBackupWriter: (backup) async {
          safetyBackupWritten = true;

          expect(backup.data.animals.single.commonName, 'Old Animal');
        },
        mediaWriter: (portablePath, bytes) async {
          expect(portablePath, 'media/animals/12.jpg');

          expect(bytes, Uint8List.fromList([1, 2, 3, 4]));

          return 'restored/12.jpg';
        },
        mediaCleanup: (_) async {},
      );

      final result = await service.restore(
        backup: createTargetBackup(),
        currentAppVersion: '0.6.0',
      );

      expect(safetyBackupWritten, isTrue);

      expect(result.boxCount, 1);

      expect(result.animalCount, 1);

      expect(result.feedingEventCount, 1);

      expect(result.mediaFileCount, 1);

      final boxes = await database.select(database.boxes).get();

      expect(boxes.length, 1);

      expect(boxes.single.id, 5);

      final animals = await database.select(database.animals).get();

      expect(animals.length, 1);

      final animal = animals.single;

      expect(animal.id, 12);

      expect(animal.boxId, 5);

      expect(animal.commonName, 'Restored Animal');

      expect(animal.picturePath, 'restored/12.jpg');

      final feedings = await database.select(database.feedingEvents).get();

      expect(feedings.length, 1);

      expect(feedings.single.id, 30);

      expect(feedings.single.animalId, 12);

      expect(settingsController.themeMode, ThemeMode.dark);

      expect(settingsController.accent, AppAccent.teal);
    },
  );

  test('safety backup failure leaves current data unchanged', () async {
    await createExistingData();

    var mediaWriterCalled = false;

    final service = BackupRestoreService(
      database: database,
      settingsController: settingsController,
      safetyBackupWriter: (_) async {
        throw Exception('Cannot save safety backup');
      },
      mediaWriter: (path, bytes) async {
        mediaWriterCalled = true;
        return 'unused.jpg';
      },
      mediaCleanup: (_) async {},
    );

    await expectLater(
      service.restore(backup: createTargetBackup(), currentAppVersion: '0.6.0'),
      throwsA(
        isA<BackupRestoreException>().having(
          (error) => error.stage,
          'stage',
          BackupRestoreStage.safetyBackup,
        ),
      ),
    );

    expect(mediaWriterCalled, isFalse);

    final animals = await database.select(database.animals).get();

    expect(animals.single.commonName, 'Old Animal');

    expect(settingsController.themeMode, ThemeMode.light);

    expect(settingsController.accent, AppAccent.red);
  });

  test(
    'media failure leaves current database and settings unchanged',
    () async {
      await createExistingData();

      final service = BackupRestoreService(
        database: database,
        settingsController: settingsController,
        safetyBackupWriter: (_) async {},
        mediaWriter: (path, bytes) async {
          throw Exception('Media write failed');
        },
        mediaCleanup: (_) async {},
      );

      await expectLater(
        service.restore(
          backup: createTargetBackup(),
          currentAppVersion: '0.6.0',
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.stage,
            'stage',
            BackupRestoreStage.media,
          ),
        ),
      );

      final animals = await database.select(database.animals).get();

      expect(animals.single.commonName, 'Old Animal');

      expect(settingsController.themeMode, ThemeMode.light);

      expect(settingsController.accent, AppAccent.red);
    },
  );

  test(
    'database failure rolls back data settings and prepared media',
    () async {
      await createExistingData();

      final cleanedPaths = <String>[];

      final service = BackupRestoreService(
        database: database,
        settingsController: settingsController,
        safetyBackupWriter: (_) async {},
        mediaWriter: (path, bytes) async {
          return 'restored/12.jpg';
        },
        mediaCleanup: (localPath) async {
          cleanedPaths.add(localPath);
        },
      );

      // Deliberately bypasses validation to force a
      // foreign-key failure inside the DB transaction.
      final invalidBackup = createTargetBackup(animalBoxId: 999);

      await expectLater(
        service.restore(backup: invalidBackup, currentAppVersion: '0.6.0'),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.stage,
            'stage',
            BackupRestoreStage.database,
          ),
        ),
      );

      final animals = await database.select(database.animals).get();

      expect(animals.length, 1);

      expect(animals.single.commonName, 'Old Animal');

      expect(settingsController.themeMode, ThemeMode.light);

      expect(settingsController.accent, AppAccent.red);

      expect(cleanedPaths, contains('restored/12.jpg'));
    },
  );

  test(
    'restored autoincrement sequence continues after restored ids',
    () async {
      await createExistingData();

      final service = BackupRestoreService(
        database: database,
        settingsController: settingsController,
        safetyBackupWriter: (_) async {},
        mediaWriter: (path, bytes) async {
          return 'unused';
        },
        mediaCleanup: (_) async {},
      );

      await service.restore(
        backup: createTargetBackup(includePicture: false),
        currentAppVersion: '0.6.0',
      );

      final nextBoxId = await database
          .into(database.boxes)
          .insert(
            BoxesCompanion.insert(
              qrId: 'TM:BOX:66666666-6666-4666-8666-666666666666',
            ),
          );

      expect(nextBoxId, 6);
    },
  );

  test('can restore an empty backup', () async {
    await createExistingData();

    final backup = ValidatedBackup(
      manifest: BackupManifest(
        backupFormatVersion: 1,
        appVersion: '0.6.0',
        databaseSchemaVersion: 2,
        createdAt: DateTime.utc(2026, 9, 2),
      ),
      data: const BackupData(boxes: [], animals: [], feedingEvents: []),
      settings: const BackupSettings(themeMode: 'system', accent: 'green'),
      mediaFiles: const {},
    );

    final service = BackupRestoreService(
      database: database,
      settingsController: settingsController,
      safetyBackupWriter: (_) async {},
      mediaWriter: (path, bytes) async {
        return 'unused';
      },
      mediaCleanup: (_) async {},
    );

    await service.restore(backup: backup, currentAppVersion: '0.6.0');

    expect(await database.select(database.boxes).get(), isEmpty);

    expect(await database.select(database.animals).get(), isEmpty);

    expect(await database.select(database.feedingEvents).get(), isEmpty);

    expect(settingsController.themeMode, ThemeMode.system);

    expect(settingsController.accent, AppAccent.green);
  });
}
