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

  test('returns the latest feeding', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-002',
          ),
        );

    final animalId = await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            tempMin: 24.0,
            tempMax: 28.0,
            humidityMin: 40.0,
            humidityMax: 60.0,
          ),
        );

    await database.into(database.feedingEvents).insert(
          FeedingEventsCompanion.insert(
            animalId: animalId,
            fedAt: DateTime(2026, 8, 13, 7, 30),
          ),
        );

    await database.into(database.feedingEvents).insert(
          FeedingEventsCompanion.insert(
            animalId: animalId,
            fedAt: DateTime(2026, 8, 20, 7, 30),
          ),
        );

    final latestFeeding =
        await repository.getLastFeeding(animalId);

    expect(
      latestFeeding,
      DateTime(2026, 8, 20, 7, 30),
    );
  });

  test('returns null when animal has never been fed', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-003',
          ),
        );

    final animalId = await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            tempMin: 24.0,
            tempMax: 28.0,
            humidityMin: 40.0,
            humidityMax: 60.0,
          ),
        );

    final latestFeeding =
        await repository.getLastFeeding(animalId);

    expect(latestFeeding, isNull);
  });
}