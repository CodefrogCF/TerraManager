import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';

import 'generated/schema_v17.dart' as v17;

void main() {
  test('v17 to v18 leaves existing Box Animal and care histories byte-for-byte unchanged', () async {
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
}
