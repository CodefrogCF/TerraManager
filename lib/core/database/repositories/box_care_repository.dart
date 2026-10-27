import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/boxes/domain/box_care_entry.dart';
import '../app_database.dart';
import '../enums/box_status.dart';

class BoxCareRepository {
  const BoxCareRepository(this.database);
  final AppDatabase database;

  Future<List<BoxCareEntry>> history(int boxId) async {
    final events =
        await (database.select(database.boxCareEvents)
              ..where((e) => e.boxId.equals(boxId))
              ..orderBy([
                (e) => OrderingTerm.desc(e.occurredAt),
                (e) => OrderingTerm.desc(e.id),
              ]))
            .get();
    return events.map(_entry).toList();
  }

  Future<BoxCareEntry?> byRequestId(String requestId) async {
    final row = await (database.select(
      database.boxCareEvents,
    )..where((e) => e.requestId.equals(requestId))).getSingleOrNull();
    return row == null ? null : _entry(row);
  }

  static BoxCareEntry _entry(BoxCareEvent event) {
    return BoxCareEntry(
      id: event.id,
      boxId: event.boxId,
      type: event.type,
      occurredAt: event.occurredAt,
      notes: event.notes,
      revision: event.revision,
      requestId: event.requestId,
    );
  }

  Future<void> _validate(int boxId, DateTime at, String? notes) async {
    final box = await (database.select(
      database.boxes,
    )..where((b) => b.id.equals(boxId))).getSingleOrNull();
    if (box == null || box.status != BoxStatus.active) {
      throw StateError('Box is not active.');
    }
    if (at.isAfter(DateTime.now())) {
      throw ArgumentError('Care event time is in the future.');
    }
    if ((notes?.trim().length ?? 0) > 10000) {
      throw ArgumentError('Notes are too long.');
    }
  }

  Future<int> add({
    required int boxId,
    required BoxCareEventType type,
    required DateTime occurredAt,
    String? notes,
    String? requestId,
  }) => database.transaction(() async {
    final normalized = _notes(notes);
    final key = requestId ?? const Uuid().v4();
    if (key.trim().isEmpty || key.length > 64) {
      throw ArgumentError('Invalid request ID.');
    }
    final previous = await byRequestId(key);
    if (previous != null) {
      if (previous.boxId != boxId ||
          previous.type != type ||
          !previous.occurredAt.isAtSameMomentAs(_seconds(occurredAt)) ||
          previous.notes != normalized) {
        throw StateError('Request ID already used for another event.');
      }
      return previous.id;
    }
    await _validate(boxId, occurredAt, normalized);
    final now = DateTime.now();
    final id = await database
        .into(database.boxCareEvents)
        .insert(
          BoxCareEventsCompanion.insert(
            boxId: boxId,
            type: type,
            occurredAt: occurredAt,
            notes: Value(normalized),
            requestId: key,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  });

  Future<bool> update({
    required int boxId,
    required int id,
    required int expectedRevision,
    required String expectedRequestId,
    required BoxCareEventType type,
    required DateTime occurredAt,
    String? notes,
  }) => database.transaction(() async {
    await _validate(boxId, occurredAt, notes);
    final changed =
        await (database.update(database.boxCareEvents)..where(
              (e) =>
                  e.id.equals(id) &
                  e.boxId.equals(boxId) &
                  e.revision.equals(expectedRevision) &
                  e.requestId.equals(expectedRequestId),
            ))
            .write(
              BoxCareEventsCompanion(
                type: Value(type),
                occurredAt: Value(occurredAt),
                notes: Value(_notes(notes)),
                revision: Value(expectedRevision + 1),
                updatedAt: Value(DateTime.now()),
              ),
            );
    if (changed != 1) return false;
    return true;
  });

  Future<bool> delete({
    required int boxId,
    required int id,
    required int expectedRevision,
    required String expectedRequestId,
  }) => database.transaction(() async {
    final box = await (database.select(
      database.boxes,
    )..where((b) => b.id.equals(boxId))).getSingleOrNull();
    if (box == null || box.status != BoxStatus.active) {
      throw StateError('Box is not active.');
    }
    final changed =
        await (database.delete(database.boxCareEvents)..where(
              (e) =>
                  e.id.equals(id) &
                  e.boxId.equals(boxId) &
                  e.revision.equals(expectedRevision) &
                  e.requestId.equals(expectedRequestId),
            ))
            .go();
    if (changed != 1) return false;
    return true;
  });

  static String? _notes(String? notes) =>
      notes == null || notes.trim().isEmpty ? null : notes.trim();
  static DateTime _seconds(DateTime at) => DateTime.fromMillisecondsSinceEpoch(
    at.millisecondsSinceEpoch ~/ 1000 * 1000,
    isUtc: true,
  );
}
