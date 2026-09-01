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
            boxId: drift.Value(boxId),
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
        boxId: drift.Value(box1Id),
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
        boxId: drift.Value(box2Id),
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

  test('can create an animal', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'create-animal-box',
          ),
        );

    final animalId = await repository.createAnimal(
      boxId: boxId,
      commonName: 'Kornnatter',
      latinName: 'Pantherophis guttatus',
      sex: Sex.male,
      birthDate: DateTime(2021, 3, 15),
      birthDateAccuracy: BirthDateAccuracy.exact,
      tempMin: 24.0,
      tempMax: 28.0,
      humidityMin: 40.0,
      humidityMax: 60.0,
      picturePath: '/pictures/kornnatter.jpg',
      notes: 'Test animal',
    );

    final animal = await repository.getAnimalById(animalId);

    expect(animal, isNotNull);
    expect(animal!.boxId, boxId);
    expect(animal.commonName, 'Kornnatter');
    expect(animal.latinName, 'Pantherophis guttatus');
    expect(animal.sex, Sex.male);
    expect(animal.birthDate, DateTime(2021, 3, 15));
    expect(animal.birthDateAccuracy, BirthDateAccuracy.exact);
    expect(animal.tempMin, 24.0);
    expect(animal.tempMax, 28.0);
    expect(animal.humidityMin, 40.0);
    expect(animal.humidityMax, 60.0);
    expect(animal.picturePath, '/pictures/kornnatter.jpg');
    expect(animal.notes, 'Test animal');
  });

  test('can create an animal without optional data', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'minimal-animal-box',
          ),
        );

    final animalId = await repository.createAnimal(
      boxId: boxId,
      commonName: 'Kornnatter',
      latinName: 'Pantherophis guttatus',
      tempMin: 24.0,
      tempMax: 28.0,
      humidityMin: 40.0,
      humidityMax: 60.0,
    );

    final animal = await repository.getAnimalById(animalId);

    expect(animal, isNotNull);
    expect(animal!.sex, isNull);
    expect(animal.birthDate, isNull);
    expect(animal.birthDateAccuracy, isNull);
    expect(animal.picturePath, isNull);
    expect(animal.notes, isNull);
  });

  test('can update an animal', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'animal-update-box',
          ),
        );

    final animalId = await repository.createAnimal(
      boxId: boxId,
      commonName: 'Kornnatter',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    final updated = await repository.updateAnimal(
      animalId: animalId,
      boxId: boxId,
      commonName: 'Kornnatter',
      latinName: 'Pantherophis guttatus',
      sex: Sex.female,
      birthDate: DateTime(2021, 3, 15),
      birthDateAccuracy: BirthDateAccuracy.exact,
      tempMin: 25,
      tempMax: 29,
      humidityMin: 45,
      humidityMax: 65,
      notes: 'Aktualisierte Notizen',
    );

    expect(updated, isTrue);

    final animal = await repository.getAnimalById(animalId);

    expect(animal, isNotNull);
    expect(animal!.commonName, 'Kornnatter');
    expect(animal.latinName, 'Pantherophis guttatus');
    expect(animal.sex, Sex.female);
    expect(animal.birthDate, DateTime(2021, 3, 15));
    expect(animal.birthDateAccuracy, BirthDateAccuracy.exact);
    expect(animal.tempMin, 25);
    expect(animal.tempMax, 29);
    expect(animal.humidityMin, 45);
    expect(animal.humidityMax, 65);
    expect(animal.notes, 'Aktualisierte Notizen');
  });

  test('updateAnimal returns false when animal does not exist', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'missing-animal-box',
          ),
        );

    final updated = await repository.updateAnimal(
      animalId: 999,
      boxId: boxId,
      commonName: 'Kornnatter',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    expect(updated, isFalse);
  });

  test('can delete an animal', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'animal-delete-box',
          ),
        );

    final animalId = await repository.createAnimal(
      boxId: boxId,
      commonName: 'Kornnatter',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    final deleted = await repository.deleteAnimal(animalId);

    expect(deleted, isTrue);

    final animal = await repository.getAnimalById(animalId);

    expect(animal, isNull);
  });

  test('deleteAnimal returns false when animal does not exist', () async {
    final deleted = await repository.deleteAnimal(999);

    expect(deleted, isFalse);
  });

  test('updateAnimal can clear nullable fields', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    final animalId = await repository.createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      sex: Sex.female,
      birthDate: DateTime(2024, 5, 10),
      birthDateAccuracy: BirthDateAccuracy.exact,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      picturePath: '/images/test.jpg',
      notes: 'Some notes',
    );

    final success = await repository.updateAnimal(
      animalId: animalId,
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      sex: null,
      birthDate: null,
      birthDateAccuracy: null,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      picturePath: null,
      notes: null,
    );

    expect(success, isTrue);

    final updatedAnimal = await repository.getAnimalById(animalId);

    expect(updatedAnimal, isNotNull);
    expect(updatedAnimal!.sex, isNull);
    expect(updatedAnimal.birthDate, isNull);
    expect(updatedAnimal.birthDateAccuracy, isNull);
    expect(updatedAnimal.picturePath, isNull);
    expect(updatedAnimal.notes, isNull);
  });

  test('updateAnimal updates animal fields', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    final animalId = await repository.createAnimal(
      boxId: boxId,
      commonName: 'Old Name',
      latinName: 'Old species',
      tempMin: 20,
      tempMax: 25,
      humidityMin: 30,
      humidityMax: 50,
    );

    final success = await repository.updateAnimal(
      animalId: animalId,
      boxId: boxId,
      commonName: 'New Name',
      latinName: 'Pantherophis guttatus',
      sex: Sex.female,
      birthDate: DateTime(2024, 5, 10),
      birthDateAccuracy: BirthDateAccuracy.exact,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      notes: 'Updated notes',
    );

    expect(success, isTrue);

    final updatedAnimal = await repository.getAnimalById(animalId);

    expect(updatedAnimal, isNotNull);
    expect(updatedAnimal!.commonName, 'New Name');
    expect(updatedAnimal.latinName, 'Pantherophis guttatus');
    expect(updatedAnimal.sex, Sex.female);
    expect(updatedAnimal.birthDate, DateTime(2024, 5, 10));
    expect(
      updatedAnimal.birthDateAccuracy,
      BirthDateAccuracy.exact,
    );
    expect(updatedAnimal.tempMin, 24);
    expect(updatedAnimal.tempMax, 28);
    expect(updatedAnimal.humidityMin, 40);
    expect(updatedAnimal.humidityMax, 60);
    expect(updatedAnimal.notes, 'Updated notes');
  });
}