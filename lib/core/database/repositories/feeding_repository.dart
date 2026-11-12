import 'package:drift/drift.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/features/feedings/domain/feeding_field_values.dart';

import '../app_database.dart';
import 'custom_field_repository.dart';

class FeedingRepository {
  final AppDatabase database;

  FeedingRepository(this.database);

  Future<List<FeedingEvent>> getAllFeedings() {
    return database.select(database.feedingEvents).get();
  }

  Future<int> addFeeding(
    int animalId,
    DateTime fedAt, {
    String? notes,
    CustomFieldPatch? customFields,
  }) {
    if (customFields == null) return _insert(animalId, fedAt, notes, null);
    return database.transaction(
      () async =>
          _insert(animalId, fedAt, notes, await _applyFields(customFields)),
    );
  }

  Future<int> _insert(
    int animalId,
    DateTime fedAt,
    String? notes,
    String? fields,
  ) {
    return database
        .into(database.feedingEvents)
        .insert(
          FeedingEventsCompanion.insert(
            animalId: animalId,
            fedAt: fedAt,
            notes: notes == null ? const Value.absent() : Value(notes),
            customFieldsJson: Value.absentIfNull(fields),
          ),
        );
  }

  Future<List<int>> addFeedings({
    required Iterable<int> animalIds,
    required DateTime fedAt,
    String? notes,
    CustomFieldPatch? customFields,
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
      final fields = customFields == null
          ? null
          : await _applyFields(customFields);
      final feedingIds = <int>[];

      for (final animalId in ids) {
        feedingIds.add(await _insert(animalId, fedAt, notes, fields));
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

  Future<Map<int, DateTime>> getLatestFeedingTimes(
    Iterable<int> animalIds,
  ) async {
    final ids = animalIds.toSet().toList(growable: false);

    if (ids.isEmpty) {
      return const {};
    }

    final latestFedAt = database.feedingEvents.fedAt.max();
    final query = database.selectOnly(database.feedingEvents)
      ..addColumns([database.feedingEvents.animalId, latestFedAt])
      ..where(database.feedingEvents.animalId.isIn(ids))
      ..groupBy([database.feedingEvents.animalId]);

    final rows = await query.get();
    final latestByAnimalId = <int, DateTime>{};

    for (final row in rows) {
      final animalId = row.read(database.feedingEvents.animalId);
      final fedAt = row.read(latestFedAt);

      if (animalId != null && fedAt != null) {
        latestByAnimalId[animalId] = fedAt;
      }
    }

    return Map<int, DateTime>.unmodifiable(latestByAnimalId);
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
    CustomFieldPatch? customFields,
  }) {
    if (customFields == null) {
      return _update(feedingId, fedAt, notes, const Value.absent());
    }
    return database.transaction(() async {
      final current = await getFeedingById(feedingId);
      if (current == null) return false;
      final fields = await _applyFields(
        customFields,
        existing: decodeFeedingFieldValues(current.customFieldsJson),
      );
      return _update(feedingId, fedAt, notes, Value(fields));
    });
  }

  Future<bool> _update(
    int feedingId,
    DateTime fedAt,
    String? notes,
    Value<String?> fields,
  ) async {
    final updatedRows =
        await (database.update(
          database.feedingEvents,
        )..where((event) => event.id.equals(feedingId))).write(
          FeedingEventsCompanion(
            fedAt: Value(fedAt),
            notes: Value<String?>(notes),
            customFieldsJson: fields,
          ),
        );

    return updatedRows == 1;
  }

  Future<String?> _applyFields(
    CustomFieldPatch patch, {
    List<FeedingFieldValue>? existing,
  }) async {
    final updates = CustomFieldPatch.fromJson(patch.toJson());
    final revision = existing == null ? null : feedingFieldRevision(existing);
    if (revision != updates.expectedRevision) throw CustomFieldConflict();
    final templates = await CustomFieldRepository(database)
        .templates(CustomFieldTarget.feeding);
    final byId = {for (final template in templates) template.id: template};
    final values = {
      for (final field in existing ?? const <FeedingFieldValue>[])
        field.template.id: field,
    };
    for (final update in updates.updates) {
      final template = byId[update.id];
      if (template == null ||
          template.archived ||
          template.hidden ||
          template.revision != update.templateRevision) {
        throw CustomFieldConflict();
      }
      final value = template.validate(update.value);
      if (value == null) {
        values.remove(update.id);
      } else if (!sameFieldValue(values[update.id]?.value, value)) {
        values[update.id] = FeedingFieldValue(template, value);
      }
    }
    return encodeFeedingFieldValues(values.values.toList());
  }

  Future<bool> deleteFeeding(int feedingId) async {
    final deletedRows = await (database.delete(
      database.feedingEvents,
    )..where((event) => event.id.equals(feedingId))).go();

    return deletedRows == 1;
  }
}
