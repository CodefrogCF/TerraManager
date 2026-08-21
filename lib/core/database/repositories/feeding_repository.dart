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
}