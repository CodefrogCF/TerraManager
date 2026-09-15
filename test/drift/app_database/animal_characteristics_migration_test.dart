import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';

import 'generated/schema_v8.dart' as v8;

void main() {
  test(
    'v8 to v9 preserves Animals and initializes optional characteristics',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'animal-characteristics-v8-v9-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = v8.DatabaseAtV8(NativeDatabase(file));

      try {
        final boxId = await old
            .into(old.boxes)
            .insert(
              v8.BoxesCompanion.insert(
                qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
                name: const Value('Existing Box'),
              ),
            );
        await old
            .into(old.animals)
            .insert(
              v8.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Existing Animal',
                latinName: 'Test species',
                tempMin: 20,
                tempMax: 30,
                humidityMin: 40,
                humidityMax: 60,
                notes: const Value('Preserved notes'),
              ),
            );
      } finally {
        await old.close();
      }

      final migrated = AppDatabase.test(NativeDatabase(file));
      addTearDown(migrated.close);
      final animal = await migrated.select(migrated.animals).getSingle();

      expect(animal.commonName, 'Existing Animal');
      expect(animal.notes, 'Preserved notes');
      expect(animal.originHabitat, isNull);
      expect(animal.weight, isNull);
      expect(animal.sheddingNotes, isNull);
      expect(animal.restOrDormancyPeriods, isNull);
      expect(animal.temperatureZones, isNull);
      expect(
        await migrated.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}
