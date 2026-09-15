import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_category.dart';

import 'generated/schema_v9.dart' as v9;

void main() {
  test(
    'v9 to v10 preserves Animals and initializes fallback taxonomy',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'animal-taxonomy-v9-v10-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = v9.DatabaseAtV9(NativeDatabase(file));

      try {
        final boxId = await old
            .into(old.boxes)
            .insert(
              v9.BoxesCompanion.insert(
                qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
                name: const Value('Existing Box'),
              ),
            );
        await old
            .into(old.animals)
            .insert(
              v9.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Existing Animal',
                latinName: 'Test species',
                tempMin: 20,
                tempMax: 30,
                humidityMin: 40,
                humidityMax: 60,
              ),
            );
      } finally {
        await old.close();
      }

      final migrated = AppDatabase.test(NativeDatabase(file));
      addTearDown(migrated.close);
      final animal = await migrated.select(migrated.animals).getSingle();

      expect(migrated.schemaVersion, 10);
      expect(animal.commonName, 'Existing Animal');
      expect(animal.category, AnimalCategory.other);
      expect(animal.subcategory, isNull);
      expect(
        await migrated.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}
