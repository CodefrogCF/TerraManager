// dart format width=80
// ignore_for_file: unused_local_variable, unused_import

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    const versions = GeneratedHelper.versions;

    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);

            final db = AppDatabase(schema.newConnection());

            await verifier.migrateAndValidate(db, toVersion);

            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 preserves existing data', () async {
    int unixSeconds(DateTime value) {
      return value.millisecondsSinceEpoch ~/ 1000;
    }

    final boxCreatedAt = unixSeconds(DateTime(2026, 8, 20, 10, 0));

    final boxUpdatedAt = unixSeconds(DateTime(2026, 8, 21, 11, 30));

    final animalCreatedAt = unixSeconds(DateTime(2026, 8, 20, 10, 15));

    final animalUpdatedAt = unixSeconds(DateTime(2026, 8, 22, 14, 45));

    final fedAt = unixSeconds(DateTime(2026, 8, 23, 18, 30));

    final oldBoxesData = <v1.BoxesData>[
      v1.BoxesData(
        id: 1,
        qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
        createdAt: boxCreatedAt,
        updatedAt: boxUpdatedAt,
      ),
    ];

    final expectedNewBoxesData = <v2.BoxesData>[
      v2.BoxesData(
        id: 1,
        qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
        createdAt: boxCreatedAt,
        updatedAt: boxUpdatedAt,
      ),
    ];

    final oldAnimalsData = <v1.AnimalsData>[
      v1.AnimalsData(
        id: 1,
        boxId: 1,
        commonName: 'Corn Snake',
        latinName: 'Pantherophis guttatus',
        sex: null,
        birthDate: null,
        birthDateAccuracy: null,
        tempMin: 24,
        tempMax: 28,
        humidityMin: 40,
        humidityMax: 60,
        picturePath: null,
        notes: 'Existing animal before migration',
        createdAt: animalCreatedAt,
        updatedAt: animalUpdatedAt,
      ),
    ];

    final expectedNewAnimalsData = <v2.AnimalsData>[
      v2.AnimalsData(
        id: 1,
        boxId: 1,
        status: 'active',
        commonName: 'Corn Snake',
        latinName: 'Pantherophis guttatus',
        sex: null,
        birthDate: null,
        birthDateAccuracy: null,
        tempMin: 24,
        tempMax: 28,
        humidityMin: 40,
        humidityMax: 60,
        picturePath: null,
        notes: 'Existing animal before migration',
        archiveReason: null,
        archivedAt: null,
        archiveNotes: null,
        createdAt: animalCreatedAt,
        updatedAt: animalUpdatedAt,
      ),
    ];

    final oldFeedingEventsData = <v1.FeedingEventsData>[
      v1.FeedingEventsData(
        id: 1,
        animalId: 1,
        fedAt: fedAt,
        notes: 'Existing feeding before migration',
      ),
    ];

    final expectedNewFeedingEventsData = <v2.FeedingEventsData>[
      v2.FeedingEventsData(
        id: 1,
        animalId: 1,
        fedAt: fedAt,
        notes: 'Existing feeding before migration',
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.boxes, oldBoxesData);

        batch.insertAll(oldDb.animals, oldAnimalsData);

        batch.insertAll(oldDb.feedingEvents, oldFeedingEventsData);
      },
      validateItems: (newDb) async {
        final boxes = await newDb.select(newDb.boxes).get();

        final animals = await newDb.select(newDb.animals).get();

        final feedingEvents = await newDb.select(newDb.feedingEvents).get();

        expect(boxes, expectedNewBoxesData);

        expect(animals, expectedNewAnimalsData);

        expect(feedingEvents, expectedNewFeedingEventsData);

        // Existing animals become active after migration.
        expect(animals.single.status, 'active');

        // Existing box assignment is preserved.
        expect(animals.single.boxId, 1);

        // New archive fields are empty for existing animals.
        expect(animals.single.archiveReason, isNull);

        expect(animals.single.archivedAt, isNull);

        expect(animals.single.archiveNotes, isNull);

        // Existing feeding history remains associated with the animal.
        expect(feedingEvents.single.animalId, animals.single.id);
      },
    );
  });

  test(
    'migration from v2 to v3 preserves existing data and adds media support',
    () async {
      int unixSeconds(DateTime value) {
        return value.millisecondsSinceEpoch ~/ 1000;
      }

      final createdAt = unixSeconds(DateTime(2026, 9, 1, 10));

      final updatedAt = unixSeconds(DateTime(2026, 9, 2, 12));

      final oldBoxesData = <v2.BoxesData>[
        v2.BoxesData(
          id: 1,
          qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      ];

      final oldAnimalsData = <v2.AnimalsData>[
        v2.AnimalsData(
          id: 1,
          boxId: 1,
          status: 'active',
          commonName: 'Corn Snake',
          latinName: 'Pantherophis guttatus',
          sex: 'female',
          birthDate: null,
          birthDateAccuracy: null,
          tempMin: 24,
          tempMax: 28,
          humidityMin: 40,
          humidityMax: 60,
          picturePath: 'legacy/animal.jpg',
          notes: 'Existing animal',
          archiveReason: null,
          archivedAt: null,
          archiveNotes: null,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      ];

      final expectedAnimals = <v3.AnimalsData>[
        v3.AnimalsData(
          id: 1,
          boxId: 1,
          status: 'active',
          commonName: 'Corn Snake',
          latinName: 'Pantherophis guttatus',
          sex: 'female',
          birthDate: null,
          birthDateAccuracy: null,
          tempMin: 24,
          tempMax: 28,
          humidityMin: 40,
          humidityMax: 60,
          picturePath: 'legacy/animal.jpg',
          pictureMediaId: null,
          notes: 'Existing animal',
          archiveReason: null,
          archivedAt: null,
          archiveNotes: null,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.boxes, oldBoxesData);

          batch.insertAll(oldDb.animals, oldAnimalsData);
        },
        validateItems: (newDb) async {
          final boxes = await newDb.select(newDb.boxes).get();

          final animals = await newDb.select(newDb.animals).get();

          final media = await newDb.select(newDb.mediaAssets).get();

          expect(boxes.length, 1);

          expect(animals, expectedAnimals);

          expect(media, isEmpty);

          // Legacy picturePath is preserved.
          expect(animals.single.picturePath, 'legacy/animal.jpg');

          // No MediaAsset is fabricated during
          // the schema migration.
          expect(animals.single.pictureMediaId, isNull);
        },
      );
    },
  );

  test(
    'migration from v3 to v4 preserves existing boxes and adds box metadata',
    () async {
      int unixSeconds(DateTime value) {
        return value.millisecondsSinceEpoch ~/ 1000;
      }

      final createdAt = unixSeconds(DateTime(2026, 9, 2, 10));

      final updatedAt = unixSeconds(DateTime(2026, 9, 3, 8));

      final oldBoxesData = <v3.BoxesData>[
        v3.BoxesData(
          id: 1,
          qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      ];

      final expectedBoxes = <v4.BoxesData>[
        v4.BoxesData(
          id: 1,
          qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
          widthCm: null,
          heightCm: null,
          depthCm: null,
          pictureMediaId: null,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.boxes, oldBoxesData);
        },
        validateItems: (newDb) async {
          final boxes = await newDb.select(newDb.boxes).get();

          expect(boxes, expectedBoxes);

          expect(boxes.single.widthCm, isNull);
          expect(boxes.single.heightCm, isNull);
          expect(boxes.single.depthCm, isNull);
          expect(boxes.single.pictureMediaId, isNull);

          // Permanent QR identifier survives unchanged.
          expect(
            boxes.single.qrId,
            'TM:BOX:12345678-1234-4123-8123-123456789abc',
          );
        },
      );
    },
  );

  test(
    'migration from v4 to current preserves Animals and disables reminders',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'terramanager-v4-v5-',
      );
      final databaseFile = File('${directory.path}/terramanager.sqlite');

      v4.DatabaseAtV4? oldDatabase;
      AppDatabase? migratedDatabase;

      try {
        oldDatabase = v4.DatabaseAtV4(NativeDatabase(databaseFile));

        final boxId = await oldDatabase
            .into(oldDatabase.boxes)
            .insert(
              v4.BoxesCompanion.insert(
                qrId: 'TM:BOX:55555555-5555-4555-8555-555555555555',
              ),
            );

        await oldDatabase
            .into(oldDatabase.animals)
            .insert(
              v4.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Existing Animal',
                latinName: 'Test species',
                tempMin: 24,
                tempMax: 28,
                humidityMin: 40,
                humidityMax: 60,
                notes: const Value('Preserve me'),
              ),
            );

        await oldDatabase.close();
        oldDatabase = null;

        final openedDatabase = AppDatabase.test(NativeDatabase(databaseFile));
        migratedDatabase = openedDatabase;

        final animal = await openedDatabase
            .select(openedDatabase.animals)
            .getSingle();

        expect(openedDatabase.schemaVersion, 6);
        expect(animal.commonName, 'Existing Animal');
        expect(animal.notes, 'Preserve me');
        expect(animal.feedingReminderIntervalDays, isNull);
        expect(animal.feedingReminderBaseline, isNull);

        final columns = await openedDatabase
            .customSelect('PRAGMA table_info(animals)')
            .get();
        final columnNames = columns
            .map((row) => row.read<String>('name'))
            .toSet();

        expect(columnNames, contains('feeding_reminder_interval_days'));
        expect(columnNames, contains('feeding_reminder_baseline'));
      } finally {
        await oldDatabase?.close();
        await migratedDatabase?.close();

        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
  );

  test(
    'migration from v5 to v6 preserves Boxes and adds empty notes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'terramanager-v5-v6-',
      );
      final databaseFile = File('${directory.path}/terramanager.sqlite');

      v5.DatabaseAtV5? oldDatabase;
      AppDatabase? migratedDatabase;

      try {
        oldDatabase = v5.DatabaseAtV5(NativeDatabase(databaseFile));

        final mediaId = await oldDatabase
            .into(oldDatabase.mediaAssets)
            .insert(
              v5.MediaAssetsCompanion.insert(
                fileName: 'existing-box.webp',
                mimeType: 'image/webp',
                data: Uint8List.fromList([1, 2, 3, 4]),
              ),
            );

        final boxId = await oldDatabase
            .into(oldDatabase.boxes)
            .insert(
              v5.BoxesCompanion.insert(
                qrId: 'TM:BOX:77777777-7777-4777-8777-777777777777',
                widthCm: const Value(60),
                heightCm: const Value(45),
                depthCm: const Value(40),
                pictureMediaId: Value(mediaId),
              ),
            );

        final animalId = await oldDatabase
            .into(oldDatabase.animals)
            .insert(
              v5.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Existing Animal',
                latinName: 'Test species',
                tempMin: 24,
                tempMax: 28,
                humidityMin: 40,
                humidityMax: 60,
                notes: const Value('Preserve Animal notes'),
                feedingReminderIntervalDays: const Value(7),
                feedingReminderBaseline: const Value(1788264000),
              ),
            );

        await oldDatabase
            .into(oldDatabase.feedingEvents)
            .insert(
              v5.FeedingEventsCompanion.insert(
                animalId: animalId,
                fedAt: 1788267600,
                notes: const Value('Preserve feeding'),
              ),
            );

        await oldDatabase.close();
        oldDatabase = null;

        final openedDatabase = AppDatabase.test(NativeDatabase(databaseFile));
        migratedDatabase = openedDatabase;

        final box = await openedDatabase
            .select(openedDatabase.boxes)
            .getSingle();
        final media = await openedDatabase
            .select(openedDatabase.mediaAssets)
            .getSingle();
        final animal = await openedDatabase
            .select(openedDatabase.animals)
            .getSingle();
        final feeding = await openedDatabase
            .select(openedDatabase.feedingEvents)
            .getSingle();

        expect(openedDatabase.schemaVersion, 6);
        expect(box.qrId, 'TM:BOX:77777777-7777-4777-8777-777777777777');
        expect(box.widthCm, 60);
        expect(box.heightCm, 45);
        expect(box.depthCm, 40);
        expect(box.notes, isNull);
        expect(box.pictureMediaId, media.id);
        expect(media.fileName, 'existing-box.webp');
        expect(media.data, Uint8List.fromList([1, 2, 3, 4]));
        expect(animal.boxId, box.id);
        expect(animal.notes, 'Preserve Animal notes');
        expect(animal.feedingReminderIntervalDays, 7);
        expect(feeding.animalId, animal.id);
        expect(feeding.notes, 'Preserve feeding');

        final columns = await openedDatabase
            .customSelect('PRAGMA table_info(boxes)')
            .get();
        final columnNames = columns
            .map((row) => row.read<String>('name'))
            .toSet();

        expect(columnNames, contains('notes'));
      } finally {
        await oldDatabase?.close();
        await migratedDatabase?.close();

        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
  );

  test('schema v6 persists Box notes after reopening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terramanager-v6-reopen-',
    );
    final databaseFile = File('${directory.path}/terramanager.sqlite');

    AppDatabase? openDatabase;

    try {
      final createdDatabase = AppDatabase.test(NativeDatabase(databaseFile));
      openDatabase = createdDatabase;

      await createdDatabase
          .into(createdDatabase.boxes)
          .insert(
            BoxesCompanion.insert(
              qrId: 'TM:BOX:88888888-8888-4888-8888-888888888888',
              notes: const Value('Persistent Box notes'),
            ),
          );

      await createdDatabase.close();
      openDatabase = null;

      final reopenedDatabase = AppDatabase.test(NativeDatabase(databaseFile));
      openDatabase = reopenedDatabase;

      final box = await reopenedDatabase
          .select(reopenedDatabase.boxes)
          .getSingle();

      expect(box.notes, 'Persistent Box notes');
    } finally {
      await openDatabase?.close();

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });

  test(
    'current schema persists reminder configuration after reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'terramanager-reminder-reopen-',
      );
      final databaseFile = File('${directory.path}/terramanager.sqlite');
      final baseline = DateTime(2026, 9, 8, 15, 30);

      AppDatabase? openDatabase;

      try {
        final createdDatabase = AppDatabase.test(NativeDatabase(databaseFile));
        openDatabase = createdDatabase;

        final boxId = await createdDatabase
            .into(createdDatabase.boxes)
            .insert(
              BoxesCompanion.insert(
                qrId: 'TM:BOX:66666666-6666-4666-8666-666666666666',
              ),
            );

        await createdDatabase
            .into(createdDatabase.animals)
            .insert(
              AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Persistent Animal',
                latinName: 'Persistent species',
                tempMin: 24,
                tempMax: 28,
                humidityMin: 40,
                humidityMax: 60,
                feedingReminderIntervalDays: const Value(7),
                feedingReminderBaseline: Value(baseline),
              ),
            );

        await createdDatabase.close();
        openDatabase = null;

        final reopenedDatabase = AppDatabase.test(NativeDatabase(databaseFile));
        openDatabase = reopenedDatabase;

        final animal = await reopenedDatabase
            .select(reopenedDatabase.animals)
            .getSingle();

        expect(animal.feedingReminderIntervalDays, 7);
        expect(animal.feedingReminderBaseline, baseline);
      } finally {
        await openDatabase?.close();

        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
  );
}
