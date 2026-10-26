import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/boxes/domain/box_care_entry.dart';
import '../app_database.dart';
import '../enums/box_status.dart';
import 'picture_gallery_repository.dart';

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
    return [for (final event in events) await _entry(event)];
  }

  Future<BoxCareEntry?> byRequestId(String requestId) async {
    final row = await (database.select(
      database.boxCareEvents,
    )..where((e) => e.requestId.equals(requestId))).getSingleOrNull();
    return row == null ? null : _entry(row);
  }

  Future<List<int>> mediaIdsForBox(int boxId) async {
    final rows = await (database.select(database.boxCareEventAttachments).join([
      innerJoin(
        database.boxCareEvents,
        database.boxCareEvents.id.equalsExp(
          database.boxCareEventAttachments.eventId,
        ),
      ),
    ])..where(database.boxCareEvents.boxId.equals(boxId))).get();
    return rows
        .map((r) => r.readTable(database.boxCareEventAttachments).mediaAssetId)
        .toSet()
        .toList();
  }

  Future<BoxCareEntry> _entry(BoxCareEvent event) async {
    final attachments =
        await (database.select(database.boxCareEventAttachments)
              ..where((a) => a.eventId.equals(event.id))
              ..orderBy([(a) => OrderingTerm.asc(a.mediaAssetId)]))
            .get();
    return BoxCareEntry(
      id: event.id,
      boxId: event.boxId,
      type: event.type,
      occurredAt: event.occurredAt,
      notes: event.notes,
      mediaIds: attachments.map((a) => a.mediaAssetId).toList(),
      revision: event.revision,
      requestId: event.requestId,
    );
  }

  Future<void> _validate(
    int boxId,
    DateTime at,
    String? notes,
    List<int> mediaIds,
  ) async {
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
    if (mediaIds.length > 20 || mediaIds.toSet().length != mediaIds.length) {
      throw ArgumentError('At most 20 distinct pictures may be attached.');
    }
    final linked = await mediaIdsForBox(boxId);
    for (final id in mediaIds) {
      // Existing event attachments may remain after their gallery picture is
      // removed. New links must belong to this Box's gallery or care history.
      final gallery =
          await (database.select(database.boxPictureAssociations)..where(
                (p) => p.boxId.equals(boxId) & p.mediaAssetId.equals(id),
              ))
              .getSingleOrNull();
      if (gallery == null && !linked.contains(id)) {
        throw ArgumentError('Picture does not belong to this Box.');
      }
    }
  }

  Future<int> add({
    required int boxId,
    required BoxCareEventType type,
    required DateTime occurredAt,
    String? notes,
    List<int> mediaIds = const [],
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
          previous.notes != normalized ||
          (previous.mediaIds.length != mediaIds.length ||
              !previous.mediaIds.toSet().containsAll(mediaIds))) {
        throw StateError('Request ID already used for another event.');
      }
      return previous.id;
    }
    await _validate(boxId, occurredAt, normalized, mediaIds);
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
    await _attachments(id, mediaIds);
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
    List<int> mediaIds = const [],
  }) => database.transaction(() async {
    await _validate(boxId, occurredAt, notes, mediaIds);
    final old = await (database.select(
      database.boxCareEventAttachments,
    )..where((a) => a.eventId.equals(id))).get();
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
    await (database.delete(
      database.boxCareEventAttachments,
    )..where((a) => a.eventId.equals(id))).go();
    await _attachments(id, mediaIds);
    await PictureGalleryRepository(database)
        .deleteUnreferencedMedia(old.map((a) => a.mediaAssetId));
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
    final old = await (database.select(
      database.boxCareEventAttachments,
    )..where((a) => a.eventId.equals(id))).get();
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
    await PictureGalleryRepository(database)
        .deleteUnreferencedMedia(old.map((a) => a.mediaAssetId));
    return true;
  });

  Future<void> _attachments(int id, List<int> mediaIds) async {
    for (final mediaId in mediaIds) {
      await database
          .into(database.boxCareEventAttachments)
          .insert(
            BoxCareEventAttachmentsCompanion.insert(
              eventId: id,
              mediaAssetId: mediaId,
            ),
          );
    }
  }

  static String? _notes(String? notes) =>
      notes == null || notes.trim().isEmpty ? null : notes.trim();
  static DateTime _seconds(DateTime at) => DateTime.fromMillisecondsSinceEpoch(
    at.millisecondsSinceEpoch ~/ 1000 * 1000,
    isUtc: true,
  );
}
