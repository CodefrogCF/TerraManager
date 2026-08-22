import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';

void main() {
  late AppDatabase database;
  late FeedingRepository repository;

  setUp(() {
    database = AppDatabase.test(
      NativeDatabase.memory(),
    );

    repository = FeedingRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('can add a feeding', () async {
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
            tempMin: 24.0,
            tempMax: 28.0,
            humidityMin: 40.0,
            humidityMax: 60.0,
          ),
        );

    final fedAt = DateTime(2026, 8, 21, 12, 30);

    final feedingId = await repository.addFeeding(
      animalId,
      fedAt,
    );

    final feeding = await (
      database.select(database.feedingEvents)
        ..where((event) => event.id.equals(feedingId))
    ).getSingle();

    expect(feeding.animalId, animalId);
    expect(feeding.fedAt, fedAt);
    expect(feeding.notes, isNull);
  });

  test('can get a feeding by id', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'feeding-get-box',
          ),
        );

    final animalId = await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            tempMin: 24,
            tempMax: 28,
            humidityMin: 40,
            humidityMax: 60,
          ),
        );

    final feedingId = await repository.addFeeding(
      animalId,
      DateTime(2026, 8, 20, 7, 30),
      notes: 'Maus',
    );

    final feeding = await repository.getFeedingById(feedingId);

    expect(feeding, isNotNull);
    expect(feeding!.id, feedingId);
    expect(feeding.animalId, animalId);
    expect(feeding.fedAt, DateTime(2026, 8, 20, 7, 30));
    expect(feeding.notes, 'Maus');
  });

  test('returns null when feeding does not exist', () async {
    final feeding = await repository.getFeedingById(999);

    expect(feeding, isNull);
  });

  test('can update a feeding', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'feeding-update-box',
          ),
        );

    final animalId = await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            tempMin: 24,
            tempMax: 28,
            humidityMin: 40,
            humidityMax: 60,
          ),
        );

    final feedingId = await repository.addFeeding(
      animalId,
      DateTime(2026, 8, 20, 7, 30),
      notes: 'Alte Notiz',
    );

    final updated = await repository.updateFeeding(
      feedingId: feedingId,
      animalId: animalId,
      fedAt: DateTime(2026, 8, 21, 8, 15),
      notes: 'Neue Notiz',
    );

    expect(updated, isTrue);

    final feeding = await repository.getFeedingById(feedingId);

    expect(feeding, isNotNull);
    expect(feeding!.animalId, animalId);
    expect(feeding.fedAt, DateTime(2026, 8, 21, 8, 15));
    expect(feeding.notes, 'Neue Notiz');
  });

  test('updateFeeding returns false when feeding does not exist', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'missing-feeding-box',
          ),
        );

    final animalId = await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            tempMin: 24,
            tempMax: 28,
            humidityMin: 40,
            humidityMax: 60,
          ),
        );

    final updated = await repository.updateFeeding(
      feedingId: 999,
      animalId: animalId,
      fedAt: DateTime(2026, 8, 20, 7, 30),
      notes: 'Does not exist',
    );

    expect(updated, isFalse);
  });

  test('can delete a feeding', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'feeding-delete-box',
          ),
        );

    final animalId = await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            tempMin: 24,
            tempMax: 28,
            humidityMin: 40,
            humidityMax: 60,
          ),
        );

    final feedingId = await repository.addFeeding(
      animalId,
      DateTime(2026, 8, 20, 7, 30),
    );

    final deleted = await repository.deleteFeeding(feedingId);

    expect(deleted, isTrue);

    final feeding = await repository.getFeedingById(feedingId);

    expect(feeding, isNull);
  });

  test('deleteFeeding returns false when feeding does not exist', () async {
    final deleted = await repository.deleteFeeding(999);

    expect(deleted, isFalse);
  });
}