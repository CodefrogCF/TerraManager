import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';

import 'generated/schema_v10.dart' as v10;

void main() {
  test(
    'v10 upgrade adds Box temperature zones and transfers legacy Animal data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'box-temperature-zones-v10-current-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = v10.DatabaseAtV10(NativeDatabase(file));

      try {
        final migratedBoxId = await old
            .into(old.boxes)
            .insert(
              v10.BoxesCompanion.insert(
                qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
                name: const Value('Migrated Box'),
              ),
            );
        await old
            .into(old.boxes)
            .insert(
              v10.BoxesCompanion.insert(
                qrId: 'TM:BOX:22222222-2222-4222-8222-222222222222',
                name: const Value('Empty Box'),
              ),
            );
        await old
            .into(old.animals)
            .insert(
              v10.AnimalsCompanion.insert(
                boxId: Value(migratedBoxId),
                commonName: 'First Animal',
                latinName: 'Test species one',
                tempMin: 20,
                tempMax: 30,
                humidityMin: 40,
                humidityMax: 60,
                temperatureZones: const Value(' Warm side 28 °C '),
              ),
            );
        await old
            .into(old.animals)
            .insert(
              v10.AnimalsCompanion.insert(
                boxId: Value(migratedBoxId),
                commonName: 'Second Animal',
                latinName: 'Test species two',
                tempMin: 20,
                tempMax: 30,
                humidityMin: 40,
                humidityMax: 60,
                temperatureZones: const Value('Different legacy value'),
              ),
            );
      } finally {
        await old.close();
      }

      final migrated = AppDatabase.test(NativeDatabase(file));
      addTearDown(migrated.close);
      final boxes = await migrated.select(migrated.boxes).get();

      expect(boxes, hasLength(2));
      expect(boxes[0].name, 'Migrated Box');
      expect(boxes[0].temperatureZones, 'Warm side 28 °C');
      expect(boxes[1].name, 'Empty Box');
      expect(boxes[1].temperatureZones, isNull);
      expect(
        await migrated.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}
