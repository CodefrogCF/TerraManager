import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_status.dart';

import 'generated/schema_v7.dart' as v7;

void main() {
  test(
    'v7 to v8 retains every existing row and initializes Box lifecycle',
    () async {
      final directory = await Directory.systemTemp.createTemp('box-v7-v8-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = v7.DatabaseAtV7(NativeDatabase(file));
      final before = <String, List<Map<String, dynamic>>>{};
      try {
        final mediaId = await old
            .into(old.mediaAssets)
            .insert(
              v7.MediaAssetsCompanion.insert(
                fileName: 'existing.webp',
                mimeType: 'image/webp',
                data: Uint8List.fromList([1, 2, 3, 4]),
              ),
            );
        final boxId = await old
            .into(old.boxes)
            .insert(
              v7.BoxesCompanion.insert(
                qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
                name: const Value('Existing'),
                widthCm: const Value(60),
                heightCm: const Value(50),
                depthCm: const Value(40),
                notes: const Value('Box notes'),
                pictureMediaId: Value(mediaId),
              ),
            );
        await old
            .into(old.boxes)
            .insert(
              v7.BoxesCompanion.insert(
                qrId: 'TM:BOX:22222222-2222-4222-8222-222222222222',
              ),
            );
        final animalId = await old
            .into(old.animals)
            .insert(
              v7.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Active Animal',
                latinName: 'Test species',
                tempMin: 20,
                tempMax: 30,
                humidityMin: 40,
                humidityMax: 60,
                notes: const Value('Animal notes'),
                feedingReminderIntervalDays: const Value(7),
                feedingReminderBaseline: const Value(1789295400),
              ),
            );
        await old
            .into(old.animals)
            .insert(
              v7.AnimalsCompanion.insert(
                status: const Value('archived'),
                commonName: 'Archived Animal',
                latinName: 'Test species',
                tempMin: 20,
                tempMax: 30,
                humidityMin: 40,
                humidityMax: 60,
                archiveReason: const Value('sold'),
                archivedAt: const Value(1789295400),
                archiveNotes: const Value('Animal archive notes'),
              ),
            );
        await old
            .into(old.feedingEvents)
            .insert(
              v7.FeedingEventsCompanion.insert(
                animalId: animalId,
                fedAt: 1789295400,
                notes: const Value('Feeding notes'),
              ),
            );
        for (final table in [
          'boxes',
          'animals',
          'feeding_events',
          'media_assets',
        ]) {
          before[table] =
              (await old.customSelect('SELECT * FROM $table ORDER BY id').get())
                  .map((row) => row.data)
                  .toList();
        }
      } finally {
        await old.close();
      }

      final migrated = AppDatabase.test(NativeDatabase(file));
      addTearDown(migrated.close);
      for (final entry in before.entries) {
        final rows = await migrated
            .customSelect('SELECT * FROM ${entry.key} ORDER BY id')
            .get();
        final existingColumns = rows
            .map(
              (row) => <String, dynamic>{
                for (final key in entry.value.first.keys) key: row.data[key],
              },
            )
            .toList();
        expect(
          existingColumns,
          entry.value,
          reason: '${entry.key} data must be unchanged',
        );
      }
      expect(migrated.schemaVersion, 8);
      final boxes = await migrated.select(migrated.boxes).get();
      expect(boxes, hasLength(2));
      for (final box in boxes) {
        expect(box.status, BoxStatus.active);
        expect(box.archiveReason, isNull);
        expect(box.archivedAt, isNull);
        expect(box.archiveNotes, isNull);
      }
      expect(
        await migrated.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await migrated.customSelect('PRAGMA foreign_keys').getSingle())
            .read<int>('foreign_keys'),
        1,
      );
    },
  );
}
