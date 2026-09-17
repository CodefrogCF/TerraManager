import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/animal_weight_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository animals;
  late AnimalWeightRepository weights;
  late BoxRepository boxes;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    animals = AnimalRepository(database);
    weights = AnimalWeightRepository(database);
    boxes = BoxRepository(database);
  });

  tearDown(() => database.close());

  test(
    'records only changed weights and cascades permanent deletion',
    () async {
      final boxId = await boxes.createBox('weight-box');
      final firstMeasuredAt = DateTime(2026, 9, 1, 10);
      final secondMeasuredAt = DateTime(2026, 9, 10, 11);
      final animalId = await animals.createAnimal(
        boxId: boxId,
        commonName: 'Weighted Animal',
        latinName: 'Test species',
        tempMin: 20,
        tempMax: 25,
        humidityMin: 40,
        humidityMax: 60,
        weightGrams: 50,
        weightMeasuredAt: firstMeasuredAt,
      );

      await animals.updateAnimal(
        animalId: animalId,
        boxId: boxId,
        commonName: 'Renamed only',
        latinName: 'Test species',
        tempMin: 20,
        tempMax: 25,
        humidityMin: 40,
        humidityMax: 60,
        weightGrams: 50.0,
        weightMeasuredAt: DateTime(2026, 9, 5),
      );
      expect(await weights.getHistory(animalId), hasLength(1));

      await animals.updateAnimal(
        animalId: animalId,
        boxId: boxId,
        commonName: 'Renamed only',
        latinName: 'Test species',
        tempMin: 20,
        tempMax: 25,
        humidityMin: 40,
        humidityMax: 60,
        weightGrams: 55.5,
        weightMeasuredAt: secondMeasuredAt,
      );
      final history = await weights.getHistory(animalId);
      expect(history.map((entry) => entry.weightGrams), [55.5, 50]);
      expect(history.first.measuredAt, secondMeasuredAt);

      await animals.archiveAnimal(
        animalId: animalId,
        reason: AnimalArchiveReason.rehomed,
        archivedAt: DateTime(2026, 9, 12),
      );
      expect(await weights.getHistory(animalId), hasLength(2));

      await animals.permanentlyDeleteArchivedAnimal(animalId);
      expect(await weights.getHistory(animalId), isEmpty);
    },
  );

  test('duplicate starts with only the latest valid weight', () async {
    final sourceBoxId = await boxes.createBox('source-weight-box');
    final targetBoxId = await boxes.createBox('target-weight-box');
    final sourceId = await animals.createAnimal(
      boxId: sourceBoxId,
      commonName: 'Source',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      weightGrams: 10,
      weightMeasuredAt: DateTime(2026, 8, 1),
    );
    await weights.add(
      animalId: sourceId,
      weightGrams: 12,
      measuredAt: DateTime(2026, 9, 1),
    );

    final duplicateId = await animals.duplicateAnimal(
      sourceAnimalId: sourceId,
      boxId: targetBoxId,
      commonName: 'Copy',
    );

    expect(await weights.getHistory(sourceId), hasLength(2));
    final duplicateHistory = await weights.getHistory(duplicateId);
    expect(duplicateHistory, hasLength(1));
    expect(duplicateHistory.single.weightGrams, 12);
  });

  test('updates one measurement and clears legacy weight text', () async {
    final boxId = await boxes.createBox('editable-weight-box');
    final animalId = await animals.createAnimal(
      boxId: boxId,
      commonName: 'Editable',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
      weight: 'about 80 after feeding',
    );
    final entryId = await weights.add(
      animalId: animalId,
      weightGrams: 80,
      measuredAt: DateTime(2026, 9, 1),
    );

    expect((await animals.getAnimalById(animalId))!.weight, isNull);

    final updatedAt = DateTime(2026, 9, 2, 12, 30);
    expect(
      await weights.update(
        entryId: entryId,
        animalId: animalId,
        weightGrams: 81.5,
        measuredAt: updatedAt,
      ),
      isTrue,
    );

    final history = await weights.getHistory(animalId);
    expect(history, hasLength(1));
    expect(history.single.id, entryId);
    expect(history.single.weightGrams, 81.5);
    expect(history.single.measuredAt, updatedAt);
  });

  test('deletes only a measurement owned by the given animal', () async {
    final firstBoxId = await boxes.createBox('delete-weight-box-1');
    final secondBoxId = await boxes.createBox('delete-weight-box-2');
    final firstAnimalId = await animals.createAnimal(
      boxId: firstBoxId,
      commonName: 'First',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
    );
    final secondAnimalId = await animals.createAnimal(
      boxId: secondBoxId,
      commonName: 'Second',
      latinName: 'Test species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 40,
      humidityMax: 60,
    );
    final entryId = await weights.add(animalId: firstAnimalId, weightGrams: 50);

    expect(
      await weights.delete(entryId: entryId, animalId: secondAnimalId),
      isFalse,
    );
    expect(await weights.getHistory(firstAnimalId), hasLength(1));
    expect(
      await weights.delete(entryId: entryId, animalId: firstAnimalId),
      isTrue,
    );
    expect(await weights.getHistory(firstAnimalId), isEmpty);
  });
}
