import 'package:drift/drift.dart';

import '../../../features/boxes/domain/care_event_type_definition.dart';
import '../app_database.dart';

class CareEventTypeRepository {
  const CareEventTypeRepository(this.database);
  final AppDatabase database;
  static CareEventTypeDefinition definition(CareEventTypeRow row) =>
      CareEventTypeDefinition(
        id: row.id,
        label: row.label,
        sortOrder: row.sortOrder,
        archived: row.archived,
        revision: row.revision,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
  Future<List<CareEventTypeDefinition>> all() async =>
      (await (database.select(database.careEventTypes)..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.id),
              ]))
              .get())
          .map(definition)
          .toList();

  Future<CareEventTypeDefinition?> byId(String id) async {
    final row = await (database.select(
      database.careEventTypes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : definition(row);
  }

  Future<void> _unique(String label, {String? except}) async {
    final rows =
        await (database.select(database.careEventTypes)..where(
              (t) => t.labelKey.equals(CareEventTypeDefinition.labelKey(label)),
            ))
            .get();
    if (rows.any((r) => r.id != except)) {
      throw StateError('Duplicate care type label.');
    }
  }

  Future<CareEventTypeDefinition> create(String id, String label) =>
      database.transaction(() async {
        if (!CareEventTypeDefinition.validId(id)) {
          throw ArgumentError('Invalid care type ID.');
        }
        label = CareEventTypeDefinition.normalizeLabel(label);
        final previous = await byId(id);
        if (previous != null) {
          if (previous.label != label) {
            throw StateError('Care type ID already exists.');
          }
          return previous;
        }
        await _unique(label);
        final types = await all();
        final now = DateTime.now();
        await database
            .into(database.careEventTypes)
            .insert(
              CareEventTypesCompanion.insert(
                id: id,
                label: label,
                labelKey: CareEventTypeDefinition.labelKey(label),
                sortOrder: types.isEmpty
                    ? 0
                    : types
                              .map((t) => t.sortOrder)
                              .reduce((a, b) => a > b ? a : b) +
                          1,
                createdAt: now,
                updatedAt: now,
              ),
            );
        return (await byId(id))!;
      });
  Future<CareEventTypeDefinition> update({
    required String id,
    required int expectedRevision,
    required String label,
    required bool archived,
  }) => database.transaction(() async {
    label = CareEventTypeDefinition.normalizeLabel(label);
    final previous = await byId(id);
    if (previous == null || previous.revision != expectedRevision) {
      throw StateError('Care type changed.');
    }
    await _unique(label, except: id);
    final changed =
        await (database.update(database.careEventTypes)..where(
              (t) => t.id.equals(id) & t.revision.equals(expectedRevision),
            ))
            .write(
              CareEventTypesCompanion(
                label: Value(label),
                labelKey: Value(CareEventTypeDefinition.labelKey(label)),
                archived: Value(archived),
                revision: Value(expectedRevision + 1),
                updatedAt: Value(DateTime.now()),
              ),
            );
    if (changed != 1) throw StateError('Care type changed.');
    return (await byId(id))!;
  });

  /// Exact ID/revision set prevents silently overwriting another client's changes.
  Future<void> reorder(List<({String id, int revision})> order) =>
      database.transaction(() async {
        final current = await all();
        final byKey = {for (final t in current) t.id: t};
        if (order.length != current.length ||
            order.map((e) => e.id).toSet().length != order.length ||
            order.any((e) => byKey[e.id]?.revision != e.revision)) {
          throw StateError('Care type order changed.');
        }
        for (var index = 0; index < order.length; index++) {
          final item = order[index];
          await (database.update(
            database.careEventTypes,
          )..where((t) => t.id.equals(item.id))).write(
            CareEventTypesCompanion(
              sortOrder: Value(index),
              revision: Value(item.revision + 1),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      });
}
