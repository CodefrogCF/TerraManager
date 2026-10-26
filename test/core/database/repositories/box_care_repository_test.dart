import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/shared_server/media/infrastructure/media_storage_policy.dart';

void main() {
  late AppDatabase db;
  late BoxCareRepository care;
  late int box;
  late int other;
  final at = DateTime.utc(2026, 1, 1, 12);
  setUp(() async {
    db = AppDatabase.test(NativeDatabase.memory());
    care = BoxCareRepository(db);
    box = await BoxRepository(db).createBoxWithGeneratedQrId();
    other = await BoxRepository(db).createBoxWithGeneratedQrId();
  });
  tearDown(() => db.close());
  Future<int> picture(int owner) => PictureGalleryRepository(db).addBoxPicture(
    boxId: owner,
    fileName: 'care.png',
    mimeType: 'image/png',
    data: Uint8List.fromList([1, 2, 3]),
  );

  Future<String> keyFor(int id) async => (await (db.select(
    db.boxCareEvents,
  )..where((e) => e.id.equals(id))).getSingle()).requestId;

  test(
    'three structured types stay Box-owned and sort by time then ID',
    () async {
      final cleaning = await care.add(
        boxId: box,
        type: BoxCareEventType.cleaning,
        occurredAt: at,
      );
      final water = await care.add(
        boxId: box,
        type: BoxCareEventType.waterChange,
        occurredAt: at,
      );
      final substrate = await care.add(
        boxId: box,
        type: BoxCareEventType.substrateChange,
        occurredAt: at.add(const Duration(days: 1)),
        notes: '  New substrate  ',
      );
      await care.add(
        boxId: other,
        type: BoxCareEventType.cleaning,
        occurredAt: at,
      );
      final history = await care.history(box);
      expect(history.map((e) => e.id), [substrate, water, cleaning]);
      expect(history.first.notes, 'New substrate');
      expect(history.every((e) => e.boxId == box), true);
      expect(await db.select(db.feedingEvents).get(), isEmpty);
      expect(await db.select(db.sheddingEvents).get(), isEmpty);
    },
  );
  test(
    'retries reuse a persisted request; a changed payload is rejected',
    () async {
      final id = await care.add(
        boxId: box,
        type: BoxCareEventType.cleaning,
        occurredAt: at,
        requestId: 'retry',
      );
      expect(
        await care.add(
          boxId: box,
          type: BoxCareEventType.cleaning,
          occurredAt: at,
          requestId: 'retry',
        ),
        id,
      );
      await expectLater(
        care.add(
          boxId: other,
          type: BoxCareEventType.cleaning,
          occurredAt: at,
          requestId: 'retry',
        ),
        throwsStateError,
      );
      expect(await care.history(box), hasLength(1));
    },
  );
  test('editing and deletion require the matching Box and revision', () async {
    final id = await care.add(
      boxId: box,
      type: BoxCareEventType.cleaning,
      occurredAt: at,
    );
    expect(
      await care.update(
        boxId: other,
        id: id,
        expectedRevision: 1,
        expectedRequestId: await keyFor(id),
        type: BoxCareEventType.waterChange,
        occurredAt: at,
      ),
      false,
    );
    expect(
      await care.update(
        boxId: box,
        id: id,
        expectedRevision: 1,
        expectedRequestId: await keyFor(id),
        type: BoxCareEventType.waterChange,
        occurredAt: at,
      ),
      true,
    );
    expect(
      await care.update(
        boxId: box,
        id: id,
        expectedRevision: 1,
        expectedRequestId: await keyFor(id),
        type: BoxCareEventType.cleaning,
        occurredAt: at,
      ),
      false,
    );
    expect(
      await care.delete(
        boxId: box,
        id: id,
        expectedRevision: 1,
        expectedRequestId: await keyFor(id),
      ),
      false,
    );
    expect((await care.history(box)).single.type, BoxCareEventType.waterChange);
    expect(
      await care.delete(
        boxId: box,
        id: id,
        expectedRevision: 2,
        expectedRequestId: await keyFor(id),
      ),
      true,
    );
  });
  test(
    'invalid future times and foreign Box attachments change nothing',
    () async {
      await expectLater(
        care.add(
          boxId: box,
          type: BoxCareEventType.cleaning,
          occurredAt: DateTime.now().add(const Duration(days: 1)),
        ),
        throwsArgumentError,
      );
      final foreign = await picture(other);
      await expectLater(
        care.add(
          boxId: box,
          type: BoxCareEventType.cleaning,
          occurredAt: at,
          mediaIds: [foreign],
        ),
        throwsArgumentError,
      );
      expect(await care.history(box), isEmpty);
    },
  );
  test('care attachments survive gallery removal and media cleanup', () async {
    final media = await picture(box);
    final first = await care.add(
      boxId: box,
      type: BoxCareEventType.cleaning,
      occurredAt: at,
      mediaIds: [media],
    );
    final second = await care.add(
      boxId: box,
      type: BoxCareEventType.waterChange,
      occurredAt: at,
      mediaIds: [media],
    );
    await PictureGalleryRepository(db)
        .deleteBoxPicture(boxId: box, mediaId: media);
    expect(await MediaRepository(db).getMediaById(media), isNotNull);
    await MediaStoragePolicy(db).cleanUnassociatedMedia();
    expect(
      (await care.history(box)).every((e) => e.mediaIds.single == media),
      true,
    );
    await care.delete(
      boxId: box,
      id: first,
      expectedRevision: 1,
      expectedRequestId: await keyFor(first),
    );
    expect(await MediaRepository(db).getMediaById(media), isNotNull);
    await care.delete(
      boxId: box,
      id: second,
      expectedRevision: 1,
      expectedRequestId: await keyFor(second),
    );
    expect(await MediaRepository(db).getMediaById(media), isNull);
  });
  test('archive preserves history; duplicate has none; permanent delete cleans attachments', () async {
    final media = await picture(box);
    final id = await care.add(
      boxId: box,
      type: BoxCareEventType.cleaning,
      occurredAt: at,
      mediaIds: [media],
    );
    await PictureGalleryRepository(db)
        .deleteBoxPicture(boxId: box, mediaId: media);
    final duplicate = await BoxRepository(db)
        .duplicateBox(sourceBoxId: box, name: 'Copy');
    expect(await care.history(duplicate), isEmpty);
    await BoxRepository(
      db,
    ).archiveBox(boxId: box, reason: BoxArchiveReason.stored, archivedAt: at);
    expect((await care.history(box)).single.id, id);
    await expectLater(
      care.add(boxId: box, type: BoxCareEventType.cleaning, occurredAt: at),
      throwsStateError,
    );
    await expectLater(
      care.delete(
        boxId: box,
        id: id,
        expectedRevision: 1,
        expectedRequestId: await keyFor(id),
      ),
      throwsStateError,
    );
    await BoxRepository(db).permanentlyDeleteArchivedBox(box);
    expect(await care.history(box), isEmpty);
    expect(await MediaRepository(db).getMediaById(media), isNull);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('an old draft cannot edit or delete a different event after restore reuses its ID', () async {
    final id = await care.add(
      boxId: box,
      type: BoxCareEventType.cleaning,
      occurredAt: at,
      requestId: 'before-restore',
    );
    await care.delete(
      boxId: box,
      id: id,
      expectedRevision: 1,
      expectedRequestId: 'before-restore',
    );
    await db.customStatement(
      "DELETE FROM sqlite_sequence WHERE name = 'box_care_events'",
    );
    final replacement = await care.add(
      boxId: box,
      type: BoxCareEventType.waterChange,
      occurredAt: at,
      requestId: 'after-restore',
      notes: 'Replacement event',
    );
    expect(replacement, id);
    expect(
      await care.update(
        boxId: box,
        id: id,
        expectedRevision: 1,
        expectedRequestId: 'before-restore',
        type: BoxCareEventType.cleaning,
        occurredAt: at,
        notes: 'Old draft',
      ),
      false,
    );
    expect(
      await care.delete(
        boxId: box,
        id: id,
        expectedRevision: 1,
        expectedRequestId: 'before-restore',
      ),
      false,
    );
    expect((await care.history(box)).single.notes, 'Replacement event');
  });
}
