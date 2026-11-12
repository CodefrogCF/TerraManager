import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/features/feedings/domain/animal_rest_period.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

import 'generated/schema_v21.dart' as v21;
import 'generated/schema_v23.dart' as v23;

void main() {
  test('an existing database without the rest period column can save reminders after upgrade', () async {
    final directory = await Directory.systemTemp.createTemp('tm-rest-upgrade-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/data.sqlite');
    final old = v23.DatabaseAtV23(NativeDatabase(file));
    try {
      await old.customStatement('ALTER TABLE animals DROP COLUMN rest_period');
      await old.customStatement(
        "INSERT INTO animals(id, common_name, latin_name, temp_min, temp_max, humidity_min, humidity_max) "
        "VALUES (1, 'Existing Animal', 'Test species', 20, 30, 40, 60)",
      );
    } finally {
      await old.close();
    }
    final database = AppDatabase.test(NativeDatabase.createInBackground(file));
    addTearDown(database.close);
    final animals = AnimalRepository(database);
    expect((await animals.getAnimalById(1))!.restPeriod, isNull);
    expect(
      await animals.updateFeedingReminder(
        animalId: 1,
        intervalDays: null,
        baseline: null,
        restPeriod: const Value(null),
      ),
      isTrue,
    );
    final baseline = DateTime.utc(2026, 10, 21);
    final rest = AnimalRestPeriod(
      startDate: DateTime.utc(2026, 12, 1),
      endDate: DateTime.utc(2026, 12, 10),
      timeZone: 'Europe/Berlin',
    );
    expect(
      await animals.updateFeedingReminder(
        animalId: 1,
        intervalDays: 7,
        baseline: baseline,
        restPeriod: Value(rest),
      ),
      isTrue,
    );
    final saved = (await animals.getAnimalById(1))!;
    expect(saved.feedingReminderIntervalDays, 7);
    expect(saved.feedingReminderBaseline!.toUtc(), baseline);
    expect(saved.restPeriod, rest);
  });

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
