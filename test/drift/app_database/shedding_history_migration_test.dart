import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/shedding_repository.dart';

import 'generated/schema_v14.dart' as v14;

void main() {
  test(
    'v14 upgrade migrates legacy shedding notes into shedding history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shedding-history-v14-current-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final file = File('${directory.path}/database.sqlite');

      final old = v14.DatabaseAtV14(NativeDatabase(file));

      late final int animalWithNotesId;
      late final int whitespaceAnimalId;
      late final int noNotesAnimalId;
      late final int legacyUpdatedAt;

      try {
        final boxId = await old
            .into(old.boxes)
            .insert(
              v14.BoxesCompanion.insert(
                qrId: 'TM:BOX:14614614-6146-4146-8146-146146146146',
              ),
            );

        animalWithNotesId = await old
            .into(old.animals)
            .insert(
              v14.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Legacy Shed Animal',
                latinName: 'Test species one',
                tempMin: 24,
                tempMax: 28,
                humidityMin: 40,
                humidityMax: 60,
                sheddingNotes: const Value('  Complete shed, no issues  '),
              ),
            );

        whitespaceAnimalId = await old
            .into(old.animals)
            .insert(
              v14.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'Whitespace Animal',
                latinName: 'Test species two',
                tempMin: 24,
                tempMax: 28,
                humidityMin: 40,
                humidityMax: 60,
                sheddingNotes: const Value('   '),
              ),
            );

        noNotesAnimalId = await old
            .into(old.animals)
            .insert(
              v14.AnimalsCompanion.insert(
                boxId: Value(boxId),
                commonName: 'No Notes Animal',
                latinName: 'Test species three',
                tempMin: 24,
                tempMax: 28,
                humidityMin: 40,
                humidityMax: 60,
              ),
            );

        final legacyAnimal = await (old.select(
          old.animals,
        )..where((animal) => animal.id.equals(animalWithNotesId))).getSingle();

        legacyUpdatedAt = legacyAnimal.updatedAt;
      } finally {
        await old.close();
      }

      final migrated = AppDatabase.test(NativeDatabase(file));
      addTearDown(migrated.close);

      final animals = await migrated.select(migrated.animals).get();

      final history = await SheddingRepository(migrated)
          .getHistory(animalWithNotesId);

      expect(history, hasLength(1));

      final event = history.single;

      expect(event.animalId, animalWithNotesId);
      expect(event.notes, 'Complete shed, no issues');

      final expectedMigratedAt = DateTime.fromMillisecondsSinceEpoch(
        legacyUpdatedAt * 1000,
      );

      expect(event.shedAt, expectedMigratedAt);
      expect(event.createdAt, expectedMigratedAt);
      expect(event.updatedAt, expectedMigratedAt);

      final migratedAnimal = animals.singleWhere(
        (animal) => animal.id == animalWithNotesId,
      );

      final migratedWhitespaceAnimal = animals.singleWhere(
        (animal) => animal.id == whitespaceAnimalId,
      );

      final migratedNoNotesAnimal = animals.singleWhere(
        (animal) => animal.id == noNotesAnimalId,
      );

      expect(migratedAnimal.sheddingNotes, isNull);
      expect(migratedWhitespaceAnimal.sheddingNotes, isNull);
      expect(migratedNoNotesAnimal.sheddingNotes, isNull);

      expect(
        await SheddingRepository(migrated).getHistory(whitespaceAnimalId),
        isEmpty,
      );

      expect(
        await SheddingRepository(migrated).getHistory(noNotesAnimalId),
        isEmpty,
      );

      expect(migratedAnimal.commonName, 'Legacy Shed Animal');

      expect(migratedAnimal.latinName, 'Test species one');

      expect(
        await migrated.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}
