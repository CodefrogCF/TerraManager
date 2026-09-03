import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';

void main() {
  late AppDatabase database;
  late BoxRepository repository;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    repository = BoxRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('can get a box by id', () async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-001'));

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.id, boxId);
    expect(box.qrId, 'test-box-001');
  });

  test('returns null when box does not exist', () async {
    final box = await repository.getBoxById(999);

    expect(box, isNull);
  });

  test('can get a box by qr id', () async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-002'));

    final box = await repository.getBoxByQrId('test-box-002');

    expect(box, isNotNull);
    expect(box!.id, boxId);
    expect(box.qrId, 'test-box-002');
  });

  test('returns null when qr id does not exist', () async {
    final box = await repository.getBoxByQrId('does-not-exist');

    expect(box, isNull);
  });

  test('can get all boxes', () async {
    await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-003'));

    await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-004'));

    final boxes = await repository.getAllBoxes();

    expect(boxes.length, 2);
    expect(boxes[0].qrId, 'test-box-003');
    expect(boxes[1].qrId, 'test-box-004');
  });

  test('getAllBoxes returns an empty list when no boxes exist', () async {
    final boxes = await repository.getAllBoxes();

    expect(boxes, isEmpty);
  });

  test('can create a box', () async {
    final boxId = await repository.createBox('new-box');

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.qrId, 'new-box');
    expect(box.widthCm, isNull);
    expect(box.heightCm, isNull);
    expect(box.depthCm, isNull);
    expect(box.pictureMediaId, isNull);
  });

  test('can create a box with dimensions', () async {
    final boxId = await repository.createBox(
      'box-with-dimensions',
      widthCm: 60.0,
      heightCm: 45.0,
      depthCm: 45.0,
    );

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.widthCm, 60.0);
    expect(box.heightCm, 45.0);
    expect(box.depthCm, 45.0);
  });

  test('can create a box with picture media', () async {
    final mediaId = await database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: 'box.jpg',
            mimeType: 'image/jpeg',
            data: Uint8List.fromList([1, 2, 3]),
          ),
        );

    final boxId = await repository.createBox(
      'box-with-picture',
      pictureMediaId: mediaId,
    );

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.pictureMediaId, mediaId);
  });

  test('can update box dimensions without changing qr id', () async {
    final boxId = await repository.createBox('permanent-qr');

    final updated = await repository.updateBox(
      boxId: boxId,
      widthCm: const drift.Value(60.0),
      heightCm: const drift.Value(45.0),
      depthCm: const drift.Value(40.0),
    );

    expect(updated, isTrue);

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.qrId, 'permanent-qr');
    expect(box.widthCm, 60.0);
    expect(box.heightCm, 45.0);
    expect(box.depthCm, 40.0);
  });

  test('partial update preserves unchanged box fields', () async {
    final boxId = await repository.createBox(
      'partial-update',
      widthCm: 60.0,
      heightCm: 45.0,
      depthCm: 40.0,
    );

    final updated = await repository.updateBox(
      boxId: boxId,
      widthCm: const drift.Value(80.0),
    );

    expect(updated, isTrue);

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.widthCm, 80.0);
    expect(box.heightCm, 45.0);
    expect(box.depthCm, 40.0);
  });

  test('can clear box dimensions', () async {
    final boxId = await repository.createBox(
      'clear-dimensions',
      widthCm: 60.0,
      heightCm: 45.0,
      depthCm: 40.0,
    );

    final updated = await repository.updateBox(
      boxId: boxId,
      widthCm: const drift.Value<double?>(null),
      heightCm: const drift.Value<double?>(null),
      depthCm: const drift.Value<double?>(null),
    );

    expect(updated, isTrue);

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.widthCm, isNull);
    expect(box.heightCm, isNull);
    expect(box.depthCm, isNull);
  });

  test('can assign picture media to an existing box', () async {
    final boxId = await repository.createBox('picture-update');

    final mediaId = await database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: 'box.jpg',
            mimeType: 'image/jpeg',
            data: Uint8List.fromList([1, 2, 3]),
          ),
        );

    final updated = await repository.updateBox(
      boxId: boxId,
      pictureMediaId: drift.Value(mediaId),
    );

    expect(updated, isTrue);

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.pictureMediaId, mediaId);
  });

  test('replacing box picture deletes old media asset', () async {
    final oldMediaId = await database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: 'old.jpg',
            mimeType: 'image/jpeg',
            data: Uint8List.fromList([1, 2, 3]),
          ),
        );

    final newMediaId = await database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: 'new.jpg',
            mimeType: 'image/jpeg',
            data: Uint8List.fromList([4, 5, 6]),
          ),
        );

    final boxId = await repository.createBox(
      'replace-picture',
      pictureMediaId: oldMediaId,
    );

    final updated = await repository.updateBox(
      boxId: boxId,
      pictureMediaId: drift.Value(newMediaId),
    );

    expect(updated, isTrue);

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.pictureMediaId, newMediaId);

    final oldMedia = await (database.select(
      database.mediaAssets,
    )..where((media) => media.id.equals(oldMediaId))).getSingleOrNull();

    final newMedia = await (database.select(
      database.mediaAssets,
    )..where((media) => media.id.equals(newMediaId))).getSingleOrNull();

    expect(oldMedia, isNull);
    expect(newMedia, isNotNull);
  });

  test('removing box picture deletes old media asset', () async {
    final mediaId = await database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: 'remove.jpg',
            mimeType: 'image/jpeg',
            data: Uint8List.fromList([1, 2, 3]),
          ),
        );

    final boxId = await repository.createBox(
      'remove-picture',
      pictureMediaId: mediaId,
    );

    final updated = await repository.updateBox(
      boxId: boxId,
      pictureMediaId: const drift.Value<int?>(null),
    );

    expect(updated, isTrue);

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.pictureMediaId, isNull);

    final media = await (database.select(
      database.mediaAssets,
    )..where((entry) => entry.id.equals(mediaId))).getSingleOrNull();

    expect(media, isNull);
  });

  test('can delete a box', () async {
    final boxId = await repository.createBox('delete-me');

    final deleted = await repository.deleteBox(boxId);

    expect(deleted, isTrue);

    final box = await repository.getBoxById(boxId);

    expect(box, isNull);
  });

  test('deleting box also deletes associated picture media', () async {
    final mediaId = await database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: 'delete-with-box.jpg',
            mimeType: 'image/jpeg',
            data: Uint8List.fromList([1, 2, 3]),
          ),
        );

    final boxId = await repository.createBox(
      'delete-with-picture',
      pictureMediaId: mediaId,
    );

    final deleted = await repository.deleteBox(boxId);

    expect(deleted, isTrue);

    final box = await repository.getBoxById(boxId);

    final media = await (database.select(
      database.mediaAssets,
    )..where((entry) => entry.id.equals(mediaId))).getSingleOrNull();

    expect(box, isNull);
    expect(media, isNull);
  });

  test('updateBox returns false when box does not exist', () async {
    final updated = await repository.updateBox(
      boxId: 999,
      widthCm: const drift.Value(60.0),
    );

    expect(updated, isFalse);
  });

  test('failed update does not delete supplied media', () async {
    final mediaId = await database
        .into(database.mediaAssets)
        .insert(
          MediaAssetsCompanion.insert(
            fileName: 'unused.jpg',
            mimeType: 'image/jpeg',
            data: Uint8List.fromList([1, 2, 3]),
          ),
        );

    final updated = await repository.updateBox(
      boxId: 999,
      pictureMediaId: drift.Value(mediaId),
    );

    expect(updated, isFalse);

    final media = await (database.select(
      database.mediaAssets,
    )..where((entry) => entry.id.equals(mediaId))).getSingleOrNull();

    expect(media, isNotNull);
  });

  test('deleteBox returns false when box does not exist', () async {
    final deleted = await repository.deleteBox(999);

    expect(deleted, isFalse);
  });

  test('can create box with generated QR ID', () async {
    final boxId = await repository.createBoxWithGeneratedQrId();

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.qrId, startsWith('TM:BOX:'));

    expect(
      box.qrId,
      matches(
        RegExp(
          r'^TM:BOX:'
          r'[0-9a-f]{8}-'
          r'[0-9a-f]{4}-'
          r'4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('generated QR IDs are unique between boxes', () async {
    final firstId = await repository.createBoxWithGeneratedQrId();
    final secondId = await repository.createBoxWithGeneratedQrId();

    final first = await repository.getBoxById(firstId);
    final second = await repository.getBoxById(secondId);

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.qrId, isNot(second!.qrId));
  });
}
