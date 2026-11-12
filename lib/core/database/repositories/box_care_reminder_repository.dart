import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/boxes/domain/box_care_reminder.dart';
import '../app_database.dart';
import '../date_only.dart';
import '../enums/box_care_event_type.dart';
import '../enums/box_status.dart';

class BoxCareReminderRepository {
  const BoxCareReminderRepository(this.database);
  final AppDatabase database;

  Future<List<BoxCareReminder>> forBox(int boxId) async {
    final table = database.boxCareReminders;
    final rows =
        await (database.select(table)
              ..where((row) => row.boxId.equals(boxId))
              ..orderBy([(row) => OrderingTerm.asc(row.dueOn)]))
            .get();
    return rows.map(_reminder).toList();
  }

  Future<Map<int, DateTime>> nextDueDates() async =>
      _dueDates(await _nextDueQuery().get());

  Stream<Set<TableUpdate>> get changes =>
      database.tableUpdates(TableUpdateQuery.onAllTables(_sources));

  Set<TableInfo> get _sources => {
    database.boxCareReminders,
    database.boxes,
    database.careEventTypes,
  };

  Selectable<QueryRow> _nextDueQuery() {
    final builtInKeys = BoxCareEventType.builtIn
        .map((type) => "'${type.name}'")
        .join(', ');
    return database.customSelect('''
      SELECT r.box_id, MIN(r.due_on) AS due_on
      FROM box_care_reminders r
      JOIN boxes b ON b.id = r.box_id
      LEFT JOIN care_event_types t ON t.id = r.type_key
      WHERE b.status = 'active'
        AND (r.type_key IN ($builtInKeys) OR t.archived = 0)
      GROUP BY r.box_id
      ''', readsFrom: _sources);
  }

  Map<int, DateTime> _dueDates(List<QueryRow> rows) => {
    for (final row in rows)
      row.read<int>('box_id'): BoxCareReminder.parseDay(
        row.read<String>('due_on'),
      ),
  };

  Future<void> save({
    required int boxId,
    required String typeKey,
    required DateTime? dueOn,
    int? intervalDays,
    String? expectedRevision,
  }) => database.transaction(() async {
    final box = await (database.select(
      database.boxes,
    )..where((row) => row.id.equals(boxId))).getSingleOrNull();
    if (box?.status != BoxStatus.active) {
      throw StateError('Box is not active.');
    }
    if (!BoxCareReminder.isBuiltIn(typeKey)) {
      final type = await (database.select(
        database.careEventTypes,
      )..where((row) => row.id.equals(typeKey))).getSingleOrNull();
      if (type == null || (type.archived && dueOn != null)) {
        throw ArgumentError('Care type is unavailable.');
      }
    }
    final current = await _find(boxId, typeKey);
    if (current?.revision != expectedRevision) {
      throw StateError('Care reminder changed. Reload and review it.');
    }
    if (!BoxCareReminder.validInterval(intervalDays) ||
        (dueOn == null && intervalDays != null) ||
        (dueOn != null && (dueOn.year < 1 || dueOn.year > 9999))) {
      throw ArgumentError('Invalid Box care reminder schedule.');
    }
    if (dueOn == null) {
      await _remove(boxId, typeKey);
      return;
    }
    final dueDate = dateOnlyString(dueOn)!;
    if (current?.dueOn == dueDate && current?.intervalDays == intervalDays) {
      return;
    }
    await database
        .into(database.boxCareReminders)
        .insertOnConflictUpdate(
          BoxCareRemindersCompanion.insert(
            boxId: boxId,
            typeKey: typeKey,
            dueOn: dueDate,
            intervalDays: Value(intervalDays),
            lastCompletedOn: const Value(null),
            revision: const Uuid().v4(),
          ),
        );
  });

  /// Called inside the transaction that inserts a new, validated care entry.
  Future<bool> recordCompletion(
    int boxId,
    String typeKey,
    DateTime careDay,
  ) async {
    final current = await _find(boxId, typeKey);
    if (current == null) return false;
    final days = current.intervalDays;
    if (days == null) {
      await _remove(boxId, typeKey);
      return true;
    }
    final completed = dateOnlyString(careDay)!;
    final previous = current.lastCompletedOn;
    if (previous != null && completed.compareTo(previous) <= 0) return false;
    final next = careDay.add(Duration(days: days));
    await (database.update(database.boxCareReminders)..where(
          (row) => row.boxId.equals(boxId) & row.typeKey.equals(typeKey),
        ))
        .write(
          BoxCareRemindersCompanion(
            dueOn: Value(dateOnlyString(next)!),
            lastCompletedOn: Value(completed),
            revision: Value(const Uuid().v4()),
          ),
        );
    return true;
  }

  Future<BoxCareReminderRow?> _find(int boxId, String key) =>
      (database.select(database.boxCareReminders)
            ..where((row) => row.boxId.equals(boxId) & row.typeKey.equals(key)))
          .getSingleOrNull();

  Future<int> _remove(int boxId, String key) => (database.delete(
    database.boxCareReminders,
  )..where((row) => row.boxId.equals(boxId) & row.typeKey.equals(key))).go();

  BoxCareReminder _reminder(BoxCareReminderRow row) => BoxCareReminder(
    typeKey: row.typeKey,
    dueOn: BoxCareReminder.parseDay(row.dueOn),
    intervalDays: row.intervalDays,
    lastCompletedOn: row.lastCompletedOn == null
        ? null
        : BoxCareReminder.parseDay(row.lastCompletedOn!),
    revision: row.revision,
  );
}
