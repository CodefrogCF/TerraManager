import 'package:drift/drift.dart';

import '../app_database.dart';
import '../validation/animal_weight_parser.dart';

class AnimalWeightRepository {
  final AppDatabase database;

  AnimalWeightRepository(this.database);

  Future<List<AnimalWeightEntry>> getHistory(int animalId) {
    final query = database.select(database.animalWeightEntries)
      ..where((entry) => entry.animalId.equals(animalId))
      ..orderBy([
        (entry) => OrderingTerm.desc(entry.measuredAt),
        (entry) => OrderingTerm.desc(entry.id),
      ]);
    return query.get();
  }

  Future<AnimalWeightEntry?> getLatest(int animalId) {
    final query = database.select(database.animalWeightEntries)
      ..where((entry) => entry.animalId.equals(animalId))
      ..orderBy([
        (entry) => OrderingTerm.desc(entry.measuredAt),
        (entry) => OrderingTerm.desc(entry.id),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<int> add({
    required int animalId,
    required double weightGrams,
    DateTime? measuredAt,
    int? id,
  }) async {
    _validateWeight(weightGrams);
    return database.transaction(() async {
      final entryId = await database
          .into(database.animalWeightEntries)
          .insert(
            AnimalWeightEntriesCompanion(
              id: id == null ? const Value.absent() : Value(id),
              animalId: Value(animalId),
              weightGrams: Value(weightGrams),
              measuredAt: Value(measuredAt ?? DateTime.now()),
            ),
          );
      await (database.update(database.animals)
            ..where((animal) => animal.id.equals(animalId)))
          .write(const AnimalsCompanion(weight: Value(null)));
      return entryId;
    });
  }

  Future<bool> update({
    required int entryId,
    required int animalId,
    required double weightGrams,
    required DateTime measuredAt,
  }) async {
    _validateWeight(weightGrams);
    return database.transaction(() async {
      final updated =
          await (database.update(database.animalWeightEntries)..where(
                (entry) =>
                    entry.id.equals(entryId) & entry.animalId.equals(animalId),
              ))
              .write(
                AnimalWeightEntriesCompanion(
                  weightGrams: Value(weightGrams),
                  measuredAt: Value(measuredAt),
                ),
              );
      if (updated == 0) {
        return false;
      }
      await (database.update(database.animals)
            ..where((animal) => animal.id.equals(animalId)))
          .write(const AnimalsCompanion(weight: Value(null)));
      return true;
    });
  }

  Future<bool> delete({required int entryId, required int animalId}) async {
    final deleted =
        await (database.delete(database.animalWeightEntries)..where(
              (entry) =>
                  entry.id.equals(entryId) & entry.animalId.equals(animalId),
            ))
            .go();
    return deleted > 0;
  }

  Future<bool> recordIfChanged({
    required int animalId,
    required double? weightGrams,
    DateTime? measuredAt,
  }) async {
    if (weightGrams == null) {
      return false;
    }
    final latest = await getLatest(animalId);
    if (latest != null &&
        AnimalWeightParser.equivalent(latest.weightGrams, weightGrams)) {
      return false;
    }
    await add(
      animalId: animalId,
      weightGrams: weightGrams,
      measuredAt: measuredAt,
    );
    return true;
  }

  static void _validateWeight(double weightGrams) {
    if (!weightGrams.isFinite || weightGrams <= 0) {
      throw ArgumentError.value(
        weightGrams,
        'weightGrams',
        'Weight must be a positive finite number.',
      );
    }
  }
}
