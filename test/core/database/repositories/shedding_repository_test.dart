import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/shedding_repository.dart';

void main() {
  late AppDatabase database;
  late SheddingRepository repository;
  late int animalId;

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());

    final boxId = await BoxRepository(database).createBox('shedding-test-box');

    animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    repository = SheddingRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('returns empty history for Animal without shedding events', () async {
    expect(await repository.getHistory(animalId), isEmpty);
  });

  test('adds shedding event with optional notes', () async {
    final shedAt = DateTime(2026, 9, 20, 12);

    final id = await repository.add(
      animalId: animalId,
      shedAt: shedAt,
      notes: '  Complete shed  ',
    );

    final history = await repository.getHistory(animalId);

    expect(history, hasLength(1));

    final event = history.single;

    expect(event.id, id);
    expect(event.animalId, animalId);
    expect(event.shedAt, shedAt);
    expect(event.notes, 'Complete shed');
  });

  test('stores blank notes as null', () async {
    await repository.add(animalId: animalId, notes: '   ');

    final history = await repository.getHistory(animalId);

    expect(history.single.notes, isNull);
  });

  test('orders shedding history newest first', () async {
    final older = DateTime(2026, 7, 1);
    final middle = DateTime(2026, 8, 1);
    final newer = DateTime(2026, 9, 1);

    final olderId = await repository.add(animalId: animalId, shedAt: older);

    final newerId = await repository.add(animalId: animalId, shedAt: newer);

    final middleId = await repository.add(animalId: animalId, shedAt: middle);

    final history = await repository.getHistory(animalId);

    expect(history.map((event) => event.id), [newerId, middleId, olderId]);
  });

  test('uses id descending as stable fallback for equal timestamps', () async {
    final shedAt = DateTime(2026, 9, 20);

    final firstId = await repository.add(
      animalId: animalId,
      shedAt: shedAt,
      notes: 'First',
    );

    final secondId = await repository.add(
      animalId: animalId,
      shedAt: shedAt,
      notes: 'Second',
    );

    final history = await repository.getHistory(animalId);

    expect(history.map((event) => event.id), [secondId, firstId]);
  });

  test('returns latest shedding event', () async {
    await repository.add(animalId: animalId, shedAt: DateTime(2026, 8, 1));

    final latestId = await repository.add(
      animalId: animalId,
      shedAt: DateTime(2026, 9, 1),
    );

    final latest = await repository.getLatest(animalId);

    expect(latest, isNotNull);
    expect(latest!.id, latestId);
  });

  test('updates existing shedding event', () async {
    final eventId = await repository.add(
      animalId: animalId,
      shedAt: DateTime(2026, 8, 1),
      notes: 'Old note',
    );

    final updatedAt = DateTime(2026, 9, 21, 10);

    final updated = await repository.update(
      eventId: eventId,
      animalId: animalId,
      shedAt: DateTime(2026, 9, 20),
      notes: '  New note  ',
      updatedAt: updatedAt,
    );

    expect(updated, isTrue);

    final event = (await repository.getHistory(animalId)).single;

    expect(event.shedAt, DateTime(2026, 9, 20));

    expect(event.notes, 'New note');

    expect(event.updatedAt, updatedAt);
  });

  test('does not update event belonging to another Animal', () async {
    final secondBoxId = await BoxRepository(database).createBox('second-box');

    final secondAnimalId = await AnimalRepository(database).createAnimal(
      boxId: secondBoxId,
      commonName: 'Second Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    final eventId = await repository.add(animalId: animalId);

    final updated = await repository.update(
      eventId: eventId,
      animalId: secondAnimalId,
      shedAt: DateTime(2026, 9, 20),
    );

    expect(updated, isFalse);

    expect(await repository.getHistory(animalId), hasLength(1));
  });

  test('deletes shedding event', () async {
    final eventId = await repository.add(animalId: animalId);

    final deleted = await repository.delete(
      eventId: eventId,
      animalId: animalId,
    );

    expect(deleted, isTrue);

    expect(await repository.getHistory(animalId), isEmpty);
  });

  test('does not delete event belonging to another Animal', () async {
    final secondBoxId = await BoxRepository(database).createBox('second-box');

    final secondAnimalId = await AnimalRepository(database).createAnimal(
      boxId: secondBoxId,
      commonName: 'Second Snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );

    final eventId = await repository.add(animalId: animalId);

    final deleted = await repository.delete(
      eventId: eventId,
      animalId: secondAnimalId,
    );

    expect(deleted, isFalse);

    expect(await repository.getHistory(animalId), hasLength(1));
  });
}
