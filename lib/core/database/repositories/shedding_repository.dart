import 'package:drift/drift.dart';

import '../app_database.dart';

class SheddingRepository {
  final AppDatabase database;

  SheddingRepository(this.database);

  Future<List<SheddingEvent>> getHistory(int animalId) {
    final query = database.select(database.sheddingEvents)
      ..where((event) => event.animalId.equals(animalId))
      ..orderBy([
        (event) => OrderingTerm.desc(event.shedAt),
        (event) => OrderingTerm.desc(event.id),
      ]);

    return query.get();
  }

  Future<SheddingEvent?> getLatest(int animalId) {
    final query = database.select(database.sheddingEvents)
      ..where((event) => event.animalId.equals(animalId))
      ..orderBy([
        (event) => OrderingTerm.desc(event.shedAt),
        (event) => OrderingTerm.desc(event.id),
      ])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<int> add({
    required int animalId,
    DateTime? shedAt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? id,
  }) {
    final now = DateTime.now();
    final normalizedNotes = _normalizeNotes(notes);

    return database
        .into(database.sheddingEvents)
        .insert(
          SheddingEventsCompanion(
            id: id == null ? const Value.absent() : Value(id),
            animalId: Value(animalId),
            shedAt: Value(shedAt ?? now),
            notes: Value(normalizedNotes),
            createdAt: Value(createdAt ?? now),
            updatedAt: Value(updatedAt ?? now),
          ),
        );
  }

  Future<bool> update({
    required int eventId,
    required int animalId,
    required DateTime shedAt,
    String? notes,
    DateTime? updatedAt,
  }) async {
    final changed =
        await (database.update(database.sheddingEvents)..where(
              (event) =>
                  event.id.equals(eventId) & event.animalId.equals(animalId),
            ))
            .write(
              SheddingEventsCompanion(
                shedAt: Value(shedAt),
                notes: Value(_normalizeNotes(notes)),
                updatedAt: Value(updatedAt ?? DateTime.now()),
              ),
            );

    return changed > 0;
  }

  Future<bool> delete({required int eventId, required int animalId}) async {
    final deleted =
        await (database.delete(database.sheddingEvents)..where(
              (event) =>
                  event.id.equals(eventId) & event.animalId.equals(animalId),
            ))
            .go();

    return deleted > 0;
  }

  static String? _normalizeNotes(String? notes) {
    final normalized = notes?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
