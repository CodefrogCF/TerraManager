// dart format width=80
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_weight_repository.dart';

import 'generated/schema_v13.dart' as v13;

void main() {
  test(
    'Schema 13 nighttime and unambiguous gram weight migrate safely',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'terramanager-schema14-',
      );
      final file = File.fromUri(directory.uri.resolve('terramanager.sqlite'));
      v13.DatabaseAtV13? oldDatabase;
      AppDatabase? migratedDatabase;

      try {
        oldDatabase = v13.DatabaseAtV13(NativeDatabase(file));
        final boxId = await oldDatabase
            .into(oldDatabase.boxes)
            .insert(
              v13.BoxesCompanion.insert(
                qrId: 'TM:BOX:14141414-1414-4141-8141-141414141414',
              ),
            );
        await oldDatabase
            .into(oldDatabase.animals)
            .insert(
              v13.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Convertible',
                latinName: 'Test species',
                tempMin: 20,
                tempMax: 25,
                nighttimeTemperature: const Value(18),
                humidityMin: 40,
                humidityMax: 60,
                weight: const Value('125,5 g'),
              ),
            );
        await oldDatabase
            .into(oldDatabase.animals)
            .insert(
              v13.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Free form',
                latinName: 'Test species',
                tempMin: 20,
                tempMax: 25,
                humidityMin: 40,
                humidityMax: 60,
                weight: const Value('about 80 after feeding'),
              ),
            );
        await oldDatabase.close();
        oldDatabase = null;

        migratedDatabase = AppDatabase.test(NativeDatabase(file));
        final animals = await migratedDatabase
            .select(migratedDatabase.animals)
            .get();

        final converted = animals.singleWhere(
          (animal) => animal.commonName == 'Convertible',
        );
        expect(converted.nighttimeTemperatureMin, 18);
        expect(converted.nighttimeTemperatureMax, 18);
        expect(converted.weight, isNull);
        final convertedHistory = await AnimalWeightRepository(migratedDatabase)
            .getHistory(converted.id);
        expect(convertedHistory, hasLength(1));
        expect(convertedHistory.single.weightGrams, 125.5);

        final freeForm = animals.singleWhere(
          (animal) => animal.commonName == 'Free form',
        );
        expect(freeForm.weight, 'about 80 after feeding');
        expect(
          await AnimalWeightRepository(migratedDatabase)
              .getHistory(freeForm.id),
          isEmpty,
        );
      } finally {
        await oldDatabase?.close();
        await migratedDatabase?.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
  );
}
