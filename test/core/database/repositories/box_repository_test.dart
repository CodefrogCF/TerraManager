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
  });

  test('can update a box', () async {
    final boxId = await repository.createBox('old-box');

    final updated = await repository.updateBox(boxId: boxId, qrId: 'new-box');

    expect(updated, isTrue);

    final box = await repository.getBoxById(boxId);

    expect(box, isNotNull);
    expect(box!.qrId, 'new-box');
  });

  test('can delete a box', () async {
    final boxId = await repository.createBox('delete-me');

    final deleted = await repository.deleteBox(boxId);

    expect(deleted, isTrue);

    final box = await repository.getBoxById(boxId);

    expect(box, isNull);
  });

  test('updateBox returns false when box does not exist', () async {
    final updated = await repository.updateBox(
      boxId: 999,
      qrId: 'does-not-exist',
    );

    expect(updated, isFalse);
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
