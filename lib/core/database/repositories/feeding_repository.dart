import 'package:drift/drift.dart';

import '../app_database.dart';

class FeedingRepository {
  final AppDatabase database;

  FeedingRepository(this.database);

  Future<int> addFeeding(
    int animalId,
    DateTime fedAt, {
    String? notes,
  }) {
    return database.into(database.feedingEvents).insert(
          FeedingEventsCompanion.insert(
            animalId: animalId,
            fedAt: fedAt,
            notes: notes == null ? const Value.absent() : Value(notes),
          ),
        );
  }

  Future<List<FeedingEvent>> getFeedingsForAnimal(int animalId) {
    return (database.select(database.feedingEvents)
          ..where((event) => event.animalId.equals(animalId))
          ..orderBy([
            (event) => OrderingTerm(
                  expression: event.fedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<DateTime?> getLastFeeding(int animalId) async {
    final feeding = await (database.select(database.feedingEvents)
          ..where((event) => event.animalId.equals(animalId))
          ..orderBy([
            (event) => OrderingTerm(
                  expression: event.fedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();

    return feeding?.fedAt;
  }

  Future<FeedingEvent?> getFeedingById(int feedingId) {
    return (database.select(database.feedingEvents)
          ..where((event) => event.id.equals(feedingId)))
        .getSingleOrNull();
  }

  Future<bool> updateFeeding({
    required int feedingId,
    required int animalId,
    required DateTime fedAt,
    String? notes,
  }) async {
    final updatedRows = await (database.update(database.feedingEvents)
          ..where((event) => event.id.equals(feedingId)))
        .write(
      FeedingEventsCompanion(
        animalId: Value(animalId),
        fedAt: Value(fedAt),
        notes: Value.absentIfNull(notes),
      ),
    );

    return updatedRows > 0;
  }

  Future<bool> deleteFeeding(int feedingId) async {
    final deletedRows = await (database.delete(database.feedingEvents)
          ..where((event) => event.id.equals(feedingId)))
        .go();

    return deletedRows > 0;
  }
}