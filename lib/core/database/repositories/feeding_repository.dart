import 'package:drift/drift.dart';

import '../app_database.dart';

class FeedingRepository {
  final AppDatabase database;

  FeedingRepository(this.database);

  Future<List<FeedingEvent>> getAllFeedings() {
    return database.select(database.feedingEvents).get();
  }

  Future<int> addFeeding(int animalId, DateTime fedAt, {String? notes}) {
    return database
        .into(database.feedingEvents)
        .insert(
          FeedingEventsCompanion.insert(
            animalId: animalId,
            fedAt: fedAt,
            notes: notes == null ? const Value.absent() : Value(notes),
          ),
        );
  }

  Future<List<int>> addFeedings({
    required Iterable<int> animalIds,
    required DateTime fedAt,
    String? notes,
  }) {
    final ids = List<int>.unmodifiable(animalIds);

    if (ids.isEmpty) {
      throw ArgumentError.value(ids, 'animalIds', 'must not be empty');
    }

    if (ids.toSet().length != ids.length) {
      throw ArgumentError.value(
        ids,
        'animalIds',
        'must not contain duplicates',
      );
    }

    return database.transaction(() async {
      final feedingIds = <int>[];

      for (final animalId in ids) {
        feedingIds.add(await addFeeding(animalId, fedAt, notes: notes));
      }

      return List<int>.unmodifiable(feedingIds);
    });
  }

  Future<List<FeedingEvent>> getFeedingsForAnimal(int animalId) {
    return (database.select(database.feedingEvents)
          ..where((event) => event.animalId.equals(animalId))
          ..orderBy([
            (event) =>
                OrderingTerm(expression: event.fedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<FeedingEvent?> getLatestFeeding(int animalId) {
    return (database.select(database.feedingEvents)
          ..where((event) => event.animalId.equals(animalId))
          ..orderBy([
            (event) =>
                OrderingTerm(expression: event.fedAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<DateTime?> getLastFeeding(int animalId) async {
    final feeding = await getLatestFeeding(animalId);

    return feeding?.fedAt;
  }

  Future<FeedingEvent?> getFeedingById(int feedingId) {
    return (database.select(
      database.feedingEvents,
    )..where((event) => event.id.equals(feedingId))).getSingleOrNull();
  }

  Future<bool> updateFeeding({
    required int feedingId,
    required DateTime fedAt,
    String? notes,
  }) async {
    final updatedRows =
        await (database.update(
          database.feedingEvents,
        )..where((event) => event.id.equals(feedingId))).write(
          FeedingEventsCompanion(
            fedAt: Value(fedAt),
            notes: Value<String?>(notes),
          ),
        );

    return updatedRows == 1;
  }

  Future<bool> deleteFeeding(int feedingId) async {
    final deletedRows = await (database.delete(
      database.feedingEvents,
    )..where((event) => event.id.equals(feedingId))).go();

    return deletedRows == 1;
  }
}
