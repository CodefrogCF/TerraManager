import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';

void main() {
  late AppDatabase database;
  late FeedingRepository repository;
  late int boxId;

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    repository = FeedingRepository(database);
    boxId = await BoxRepository(database).createBox('batch-feeding-box');
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createAnimal(String commonName) {
    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  test('adds one FeedingEvent for every selected Animal', () async {
    final firstAnimalId = await createAnimal('First Snake');
    final secondAnimalId = await createAnimal('Second Snake');
    final fedAt = DateTime(2026, 9, 5, 18, 30);

    final feedingIds = await repository.addFeedings(
      animalIds: [firstAnimalId, secondAnimalId],
      fedAt: fedAt,
      notes: 'One mouse each',
    );

    final feedings = await repository.getAllFeedings();

    feedings.sort((first, second) => first.animalId.compareTo(second.animalId));

    expect(feedingIds, hasLength(2));
    expect(feedings.map((feeding) => feeding.animalId), [
      firstAnimalId,
      secondAnimalId,
    ]);
    expect(feedings.every((feeding) => feeding.fedAt == fedAt), isTrue);
    expect(
      feedings.every((feeding) => feeding.notes == 'One mouse each'),
      isTrue,
    );
  });

  test('rejects an empty Animal selection', () {
    expect(
      () => repository.addFeedings(
        animalIds: const [],
        fedAt: DateTime(2026, 9, 5, 18, 30),
      ),
      throwsArgumentError,
    );
  });

  test('rejects duplicate Animal IDs', () async {
    final animalId = await createAnimal('Duplicate Snake');

    expect(
      () => repository.addFeedings(
        animalIds: [animalId, animalId],
        fedAt: DateTime(2026, 9, 5, 18, 30),
      ),
      throwsArgumentError,
    );
  });

  test('rolls back all FeedingEvents when one insert fails', () async {
    final animalId = await createAnimal('Existing Snake');

    await expectLater(
      repository.addFeedings(
        animalIds: [animalId, 999999],
        fedAt: DateTime(2026, 9, 5, 18, 30),
      ),
      throwsA(anything),
    );

    expect(await repository.getAllFeedings(), isEmpty);
  });
}
