import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

import 'generated/schema_v17.dart' as v17;
import 'generated/schema_v18.dart' as v18;

void main() {
  test('v17 to current leaves existing Box Animal and care histories byte-for-byte unchanged', () async {
    final directory = await Directory.systemTemp.createTemp('tm-care-v17-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/collection.sqlite');
    final old = v17.DatabaseAtV17(NativeDatabase(file));
    final box = await old
        .into(old.boxes)
        .insert(
          v17.BoxesCompanion.insert(
            qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
            notes: const Value('Keep Box notes'),
          ),
        );
    final animal = await old
        .into(old.animals)
        .insert(
          v17.AnimalsCompanion.insert(
            boxId: Value(box),
            commonName: 'Existing Animal',
            latinName: 'Test species',
            tempMin: 20,
            tempMax: 30,
            humidityMin: 40,
            humidityMax: 60,
          ),
        );
    await old
        .into(old.feedingEvents)
        .insert(
          v17.FeedingEventsCompanion.insert(
            animalId: animal,
            fedAt: 1700000000,
            notes: const Value('feeding'),
          ),
        );
    await old
        .into(old.animalWeightEntries)
        .insert(
          v17.AnimalWeightEntriesCompanion.insert(
            animalId: animal,
            weightGrams: 12.5,
            measuredAt: 1700000001,
          ),
        );
    await old
        .into(old.sheddingEvents)
        .insert(
          v17.SheddingEventsCompanion.insert(
            animalId: animal,
            shedAt: 1700000002,
            notes: const Value('shedding'),
            createdAt: 1700000002,
            updatedAt: 1700000002,
          ),
        );
    final before = <String, List<Map<String, dynamic>>>{};
    for (final table in [
      'boxes',
      'animals',
      'feeding_events',
      'animal_weight_entries',
      'shedding_events',
    ]) {
      before[table] = (await old.customSelect('SELECT * FROM $table').get())
          .map((r) => r.data)
          .toList();
    }
    await old.close();
    final current = AppDatabase.test(NativeDatabase(file));
    try {
      for (final entry in before.entries) {
        expect(
          (await current.customSelect('SELECT * FROM ${entry.key}').get())
              .map((r) => r.data)
              .toList(),
          entry.value,
        );
      }
      expect(await BoxCareRepository(current).history(box), isEmpty);
      await BoxCareRepository(current).add(
        boxId: box,
        type: BoxCareEventType.cleaning,
        occurredAt: DateTime.utc(2026),
      );
      expect(
        await current.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await current.close();
    }
    final reopened = AppDatabase.test(NativeDatabase(file));
    try {
      expect(
        (await BoxCareRepository(reopened).history(box)).single.type,
        BoxCareEventType.cleaning,
      );
    } finally {
      await reopened.close();
    }
  });

  for (final shared in [false, true]) {
    test(
      'v18 to v19 removes care image links and preserves all other data; shared=$shared',
      () async {
        final directory = await Directory.systemTemp.createTemp('tm-care-v18-');
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/collection.sqlite');
        final old = v18.DatabaseAtV18(NativeDatabase(file));
        for (var id = 1; id <= 5; id++) {
          await old.customStatement(
            'INSERT INTO media_assets (id, file_name, mime_type, data) VALUES (?, ?, ?, ?)',
            [
              id,
              'picture$id.png',
              'image/png',
              Uint8List.fromList([id]),
            ],
          );
        }
        await old.customStatement('''
INSERT INTO boxes (id, qr_id, name, picture_media_id)
VALUES (1, 'TM:BOX:12345678-1234-4123-8123-123456789abc', 'Existing Box', 1)
''');
        await old.customStatement('''
INSERT INTO animals (id, box_id, common_name, latin_name, temp_min, temp_max,
                     humidity_min, humidity_max, picture_media_id)
VALUES (1, 1, 'Existing Animal', 'Test species', 20, 30, 40, 60, 3)
''');
        await old.customStatement('''
INSERT INTO box_picture_associations (box_id, media_asset_id, captured_at, sort_order)
VALUES (1, 1, 1700000000, 0)
''');
        await old.customStatement('''
INSERT INTO animal_picture_associations (animal_id, media_asset_id, captured_at, sort_order)
VALUES (1, 4, 1700000000, 0)
''');
        await old.customStatement('''
INSERT INTO box_care_events
 (id, box_id, type, occurred_at, notes, request_id, revision, created_at, updated_at)
VALUES (1, 1, 'cleaning', 1700000000, 'Keep care note', 'existing-care', 4, 1700000000, 1700000001)
''');
        for (var media = 1; media <= 4; media++) {
          await old.customStatement(
            'INSERT INTO box_care_event_attachments (event_id, media_asset_id) VALUES (1, ?)',
            [media],
          );
        }
        final preserved = <String, List<Map<String, dynamic>>>{};
        for (final table in [
          'boxes',
          'animals',
          'box_care_events',
          'box_picture_associations',
          'animal_picture_associations',
        ]) {
          preserved[table] =
              (await old.customSelect('SELECT * FROM $table').get())
                  .map((r) => r.data)
                  .toList();
        }
        await old.close();
        final current = shared
            ? await openServerDatabase(file)
            : AppDatabase.test(NativeDatabase(file));
        try {
          for (final entry in preserved.entries) {
            expect(
              (await current.customSelect('SELECT * FROM ${entry.key}').get())
                  .map((r) => r.data)
                  .toList(),
              entry.value,
            );
          }
          expect(
            (await current.select(current.mediaAssets).get()).map((m) => m.id),
            [1, 2, 3, 4, 5],
          );
          expect(
            await current
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE name = 'box_care_event_attachments'",
                )
                .get(),
            isEmpty,
          );
          final care = (await BoxCareRepository(current).history(1)).single;
          expect(care.notes, 'Keep care note');
          expect(care.revision, 4);
          expect(care.requestId, 'existing-care');
          expect(
            await current.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          expect(
            (await current.customSelect('PRAGMA foreign_keys').getSingle())
                .read<int>('foreign_keys'),
            1,
          );
        } finally {
          await current.close();
        }
      },
    );
  }
}
