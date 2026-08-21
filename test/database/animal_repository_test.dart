import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository repository;

  setUp(() {
    database = AppDatabase.test(
      NativeDatabase.memory(),
    );

    repository = AnimalRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('can get an animal by id', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    final animalId = await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            sex: const drift.Value(Sex.male),
            birthDate: drift.Value(
              DateTime(2021, 3, 15),
            ),
            birthDateAccuracy: const drift.Value(
              BirthDateAccuracy.exact,
            ),
            tempMin: 24.0,
            tempMax: 28.0,
            humidityMin: 40.0,
            humidityMax: 60.0,
          ),
        );

    final animal = await repository.getAnimalById(animalId);

    expect(animal, isNotNull);
    expect(animal!.id, animalId);
    expect(animal.boxId, boxId);
    expect(animal.commonName, 'Kornnatter');
    expect(animal.latinName, 'Pantherophis guttatus');
    expect(animal.sex, Sex.male);
    expect(
      animal.birthDate,
      DateTime(2021, 3, 15),
    );
    expect(
      animal.birthDateAccuracy,
      BirthDateAccuracy.exact,
    );
    expect(animal.tempMin, 24.0);
    expect(animal.tempMax, 28.0);
    expect(animal.humidityMin, 40.0);
    expect(animal.humidityMax, 60.0);
  });

  test('returns null when animal does not exist', () async {
    final animal = await repository.getAnimalById(999);

    expect(animal, isNull);
  });

  test('getAnimalsForBox returns only animals assigned to the given box', () async {
    final box1Id = await database.into(database.boxes).insert(
      BoxesCompanion.insert(qrId: 'box-1'),
    );

    final box2Id = await database.into(database.boxes).insert(
      BoxesCompanion.insert(qrId: 'box-2'),
    );

    await database.into(database.animals).insert(
      AnimalsCompanion.insert(
        boxId: box1Id,
        commonName: 'Tier 1',
        latinName: 'Animal one',
        tempMin: 20,
        tempMax: 25,
        humidityMin: 60,
        humidityMax: 70,
      ),
    );

    await database.into(database.animals).insert(
      AnimalsCompanion.insert(
        boxId: box2Id,
        commonName: 'Tier 2',
        latinName: 'Animal two',
        tempMin: 21,
        tempMax: 26,
        humidityMin: 55,
        humidityMax: 65,
      ),
    );

    final animals = await repository.getAnimalsForBox(box1Id);

    expect(animals.length, 1);
    expect(animals.first.commonName, 'Tier 1');
  });

  test('getAnimalsForBox returns an empty list when the box has no animals', () async {
    final boxId = await database.into(database.boxes).insert(
      BoxesCompanion.insert(qrId: 'empty-box'),
    );

    final animals = await repository.getAnimalsForBox(boxId);

    expect(animals, isEmpty);
  });
}