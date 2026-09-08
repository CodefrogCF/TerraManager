import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/features/feedings/application/feeding_reminder_service.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository animalRepository;
  late FeedingRepository feedingRepository;
  late int boxId;

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    animalRepository = AnimalRepository(database);
    feedingRepository = FeedingRepository(database);
    boxId = await BoxRepository(database)
        .createBox('TM:BOX:75757575-7575-4757-8757-757575757575');
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createAnimal({
    required String commonName,
    int? intervalDays,
    DateTime? baseline,
  }) {
    return animalRepository.createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: 'Species ${commonName.toLowerCase()}',
      tempMin: 20,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 70,
      feedingReminderIntervalDays: intervalDays,
      feedingReminderBaseline: baseline,
    );
  }

  test('uses the baseline when an Animal has no feedings', () async {
    final baseline = DateTime.utc(2026, 9, 1, 12, 30);
    final now = DateTime.utc(2026, 9, 7, 8);
    final animalId = await createAnimal(
      commonName: 'No Feeding',
      intervalDays: 7,
      baseline: baseline,
    );
    final service = FeedingReminderService(database, now: () => now);

    final states = await service.getReminderStates();

    expect(states, hasLength(1));

    final state = states.single;

    expect(state.animalId, animalId);
    expect(state.intervalDays, 7);
    expect(state.baseline, baseline);
    expect(state.baseline.isUtc, isTrue);
    expect(state.latestFeedingAt, isNull);
    expect(state.referenceAt, baseline);
    expect(state.dueAt, DateTime.utc(2026, 9, 8, 12, 30));
    expect(state.evaluatedAt, now);
    expect(state.isDue, isFalse);
  });

  test('becomes due at the exact calculated boundary', () async {
    final baseline = DateTime.utc(2026, 9, 1, 12);
    final dueAt = DateTime.utc(2026, 9, 8, 12);
    var now = dueAt.subtract(const Duration(microseconds: 1));
    final animalId = await createAnimal(
      commonName: 'Boundary',
      intervalDays: 7,
      baseline: baseline,
    );
    final service = FeedingReminderService(database, now: () => now);

    var state = await service.getReminderStateForAnimal(animalId);

    expect(state, isNotNull);
    expect(state!.dueAt, dueAt);
    expect(state.isDue, isFalse);

    now = dueAt;
    state = await service.getReminderStateForAnimal(animalId);

    expect(state!.isDue, isTrue);
  });

  test(
    'uses only the latest feeding that is later than the baseline',
    () async {
      final baseline = DateTime.utc(2026, 9, 10, 9);
      final animalId = await createAnimal(
        commonName: 'Multiple Feedings',
        intervalDays: 5,
        baseline: baseline,
      );
      await feedingRepository.addFeeding(
        animalId,
        DateTime.utc(2026, 9, 8, 18),
      );
      await feedingRepository.addFeeding(
        animalId,
        DateTime.utc(2026, 9, 12, 8),
      );
      await feedingRepository.addFeeding(
        animalId,
        DateTime.utc(2026, 9, 14, 20, 15),
      );
      final service = FeedingReminderService(
        database,
        now: () => DateTime.utc(2026, 9, 18),
      );

      final state = await service.getReminderStateForAnimal(animalId);

      expect(state, isNotNull);
      expect(state!.latestFeedingAt, DateTime.utc(2026, 9, 14, 20, 15));
      expect(state.latestFeedingAt!.isUtc, isTrue);
      expect(state.referenceAt, DateTime.utc(2026, 9, 14, 20, 15));
      expect(state.dueAt, DateTime.utc(2026, 9, 19, 20, 15));
      expect(state.isDue, isFalse);
    },
  );

  test('ignores a latest feeding that predates the baseline', () async {
    final baseline = DateTime.utc(2026, 9, 10, 9);
    final animalId = await createAnimal(
      commonName: 'Old Feeding',
      intervalDays: 5,
      baseline: baseline,
    );
    await feedingRepository.addFeeding(animalId, DateTime.utc(2026, 9, 8, 18));
    final service = FeedingReminderService(
      database,
      now: () => DateTime.utc(2026, 9, 15, 9),
    );

    final state = await service.getReminderStateForAnimal(animalId);

    expect(state, isNotNull);
    expect(state!.latestFeedingAt, DateTime.utc(2026, 9, 8, 18));
    expect(state.referenceAt, baseline);
    expect(state.dueAt, DateTime.utc(2026, 9, 15, 9));
    expect(state.isDue, isTrue);
  });

  test('loads latest feeding times for multiple Animals in bulk', () async {
    final baseline = DateTime.utc(2026, 9, 1);
    final firstAnimalId = await createAnimal(
      commonName: 'First Bulk Animal',
      intervalDays: 7,
      baseline: baseline,
    );
    final secondAnimalId = await createAnimal(
      commonName: 'Second Bulk Animal',
      intervalDays: 7,
      baseline: baseline,
    );
    await feedingRepository.addFeeding(firstAnimalId, DateTime.utc(2026, 9, 5));
    await feedingRepository.addFeeding(
      firstAnimalId,
      DateTime.utc(2026, 9, 10),
    );
    await feedingRepository.addFeeding(
      secondAnimalId,
      DateTime.utc(2026, 9, 8),
    );
    final service = FeedingReminderService(
      database,
      now: () => DateTime.utc(2026, 9, 12),
    );

    final states = await service.getReminderStates();
    final statesByAnimalId = {
      for (final state in states) state.animalId: state,
    };

    expect(
      statesByAnimalId[firstAnimalId]!.latestFeedingAt,
      DateTime.utc(2026, 9, 10),
    );
    expect(statesByAnimalId[firstAnimalId]!.dueAt, DateTime.utc(2026, 9, 17));
    expect(
      statesByAnimalId[secondAnimalId]!.latestFeedingAt,
      DateTime.utc(2026, 9, 8),
    );
    expect(statesByAnimalId[secondAnimalId]!.dueAt, DateTime.utc(2026, 9, 15));
  });

  test('recalculates after feeding creation, editing and deletion', () async {
    final baseline = DateTime.utc(2026, 9, 1, 10);
    final animalId = await createAnimal(
      commonName: 'Changing History',
      intervalDays: 7,
      baseline: baseline,
    );
    final service = FeedingReminderService(
      database,
      now: () => DateTime.utc(2026, 9, 20, 10),
    );

    var state = await service.getReminderStateForAnimal(animalId);

    expect(state!.dueAt, DateTime.utc(2026, 9, 8, 10));
    expect(state.isDue, isTrue);

    final firstFeedingId = await feedingRepository.addFeeding(
      animalId,
      DateTime.utc(2026, 9, 18, 10),
    );
    state = await service.getReminderStateForAnimal(animalId);

    expect(state!.dueAt, DateTime.utc(2026, 9, 25, 10));
    expect(state.isDue, isFalse);

    await feedingRepository.updateFeeding(
      feedingId: firstFeedingId,
      fedAt: DateTime.utc(2026, 9, 10, 10),
    );
    state = await service.getReminderStateForAnimal(animalId);

    expect(state!.dueAt, DateTime.utc(2026, 9, 17, 10));
    expect(state.isDue, isTrue);

    final secondFeedingId = await feedingRepository.addFeeding(
      animalId,
      DateTime.utc(2026, 9, 19, 10),
    );
    state = await service.getReminderStateForAnimal(animalId);

    expect(state!.dueAt, DateTime.utc(2026, 9, 26, 10));
    expect(state.isDue, isFalse);

    await feedingRepository.deleteFeeding(secondFeedingId);
    state = await service.getReminderStateForAnimal(animalId);

    expect(state!.dueAt, DateTime.utc(2026, 9, 17, 10));
    expect(state.isDue, isTrue);

    await feedingRepository.deleteFeeding(firstFeedingId);
    state = await service.getReminderStateForAnimal(animalId);

    expect(state!.dueAt, DateTime.utc(2026, 9, 8, 10));
    expect(state.latestFeedingAt, isNull);
  });

  test('excludes disabled and archived Animals', () async {
    await createAnimal(commonName: 'Disabled');
    final activeId = await createAnimal(
      commonName: 'Active',
      intervalDays: 7,
      baseline: DateTime.utc(2026, 9, 1),
    );
    final archivedId = await createAnimal(
      commonName: 'Archived',
      intervalDays: 7,
      baseline: DateTime.utc(2026, 8, 1),
    );
    await animalRepository.archiveAnimal(
      animalId: archivedId,
      reason: AnimalArchiveReason.rehomed,
      archivedAt: DateTime.utc(2026, 9, 2),
    );
    final service = FeedingReminderService(
      database,
      now: () => DateTime.utc(2026, 9, 20),
    );

    final states = await service.getReminderStates();

    expect(states.map((state) => state.animalId), [activeId]);
    expect(await service.getReminderStateForAnimal(archivedId), isNull);
    expect(await service.getReminderStateForAnimal(999), isNull);
  });

  test('returns due reminders with the most overdue Animal first', () async {
    final leastOverdueId = await createAnimal(
      commonName: 'Least Overdue',
      intervalDays: 7,
      baseline: DateTime.utc(2026, 9, 7),
    );
    final notDueId = await createAnimal(
      commonName: 'Not Due',
      intervalDays: 7,
      baseline: DateTime.utc(2026, 9, 18),
    );
    final mostOverdueId = await createAnimal(
      commonName: 'Most Overdue',
      intervalDays: 7,
      baseline: DateTime.utc(2026, 9, 1),
    );
    final service = FeedingReminderService(
      database,
      now: () => DateTime.utc(2026, 9, 20),
    );

    final states = await service.getReminderStates();
    final dueStates = await service.getDueReminderStates();

    expect(states.map((state) => state.animalId), [
      mostOverdueId,
      leastOverdueId,
      notDueId,
    ]);
    expect(dueStates.map((state) => state.animalId), [
      mostOverdueId,
      leastOverdueId,
    ]);
  });
}
