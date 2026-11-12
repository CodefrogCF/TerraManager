import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

import 'generated/schema_v21.dart' as v21;

void main() {
  for (final shared in [false, true]) {
    test('v21 preserves rest notes and reminders; shared=$shared', () async {
      final directory = await Directory.systemTemp.createTemp(
        'tm-rest-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/data.sqlite');
      final old = v21.DatabaseAtV21(NativeDatabase(file));
      final baseline = DateTime.utc(2026, 10, 21);
      try {
        final boxId = await old
            .into(old.boxes)
            .insert(
              v21.BoxesCompanion.insert(
                qrId: 'TM:BOX:12345678-1234-4123-8123-123456789abc',
              ),
            );
        await old
            .into(old.animals)
            .insert(
              v21.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Existing Animal',
                latinName: 'Test species',
                tempMin: 20,
                tempMax: 30,
                humidityMin: 40,
                humidityMax: 60,
                restOrDormancyPeriods: const Value('Winter notes'),
                feedingReminderIntervalDays: const Value(7),
                feedingReminderBaseline: Value(
                  baseline.millisecondsSinceEpoch ~/ 1000,
                ),
              ),
            );
      } finally {
        await old.close();
      }

      final database = shared
          ? await openServerDatabase(file)
          : AppDatabase.test(NativeDatabase(file));
      addTearDown(database.close);
      final animal = await database.select(database.animals).getSingle();
      expect(animal.restOrDormancyPeriods, 'Winter notes');
      expect(animal.restPeriod, isNull);
      expect(animal.feedingReminderIntervalDays, 7);
      expect(animal.feedingReminderBaseline!.toUtc(), baseline);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    });
  }
}
