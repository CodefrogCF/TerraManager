import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';

void main() {
  test('new Boxes are active with empty archive metadata', () async {
    final database = AppDatabase.test(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = BoxRepository(database);
    final id = await repository.createBoxWithGeneratedQrId();
    final box = (await repository.getBoxById(id))!;
    expect(box.status, BoxStatus.active);
    expect(box.archiveReason, isNull);
    expect(box.archivedAt, isNull);
    expect(box.archiveNotes, isNull);
  });

  for (final reason in BoxArchiveReason.values) {
    test(
      'archived Box with ${reason.name} survives restart and ordinary edits',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'box-lifecycle-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/database.sqlite');
        final database = AppDatabase.test(NativeDatabase(file));
        final timestamp = DateTime(2026, 9, 13, 12, 30);
        final note = reason == BoxArchiveReason.other
            ? null
            : 'Archive context\nSecond line';
        late Box original;
        late int id;
        late int mediaId;
        try {
          mediaId = await database
              .into(database.mediaAssets)
              .insert(
                MediaAssetsCompanion.insert(
                  fileName: 'box.webp',
                  mimeType: 'image/webp',
                  data: Uint8List.fromList([1, 2, 3]),
                ),
              );
          id = await BoxRepository(database).createBoxWithGeneratedQrId(
            name: 'Rainforest',
            widthCm: 60,
            heightCm: 50,
            depthCm: 40,
            notes: 'Original Box notes',
            pictureMediaId: mediaId,
          );
          original = (await BoxRepository(database).getBoxById(id))!;
          await (database.update(
            database.boxes,
          )..where((box) => box.id.equals(id))).write(
            BoxesCompanion(
              status: const Value(BoxStatus.archived),
              archiveReason: Value(reason),
              archivedAt: Value(timestamp),
              archiveNotes: Value(note),
              updatedAt: Value(timestamp),
            ),
          );
        } finally {
          await database.close();
        }

        final reopened = AppDatabase.test(NativeDatabase(file));
        addTearDown(reopened.close);
        final repository = BoxRepository(reopened);
        final archived = (await repository.getBoxById(id))!;
        expect(archived.status, BoxStatus.archived);
        expect(archived.archiveReason, reason);
        expect(archived.archivedAt, timestamp);
        expect(archived.archiveNotes, note);
        expect(archived.qrId, original.qrId);
        expect(archived.name, original.name);
        expect(archived.widthCm, original.widthCm);
        expect(archived.heightCm, original.heightCm);
        expect(archived.depthCm, original.depthCm);
        expect(archived.notes, original.notes);
        expect(archived.pictureMediaId, mediaId);
        expect(archived.createdAt, original.createdAt);
        expect(archived.updatedAt, timestamp);
        expect((await repository.getBoxByQrId(original.qrId))!.id, id);
        expect((await reopened.select(reopened.mediaAssets).getSingle()).data, [
          1,
          2,
          3,
        ]);

        expect(
          await repository.updateBox(boxId: id, name: const Value('Renamed')),
          isTrue,
        );
        final edited = (await repository.getBoxById(id))!;
        expect(edited.status, archived.status);
        expect(edited.archiveReason, archived.archiveReason);
        expect(edited.archivedAt, archived.archivedAt);
        expect(edited.archiveNotes, archived.archiveNotes);
      },
    );
  }
}
