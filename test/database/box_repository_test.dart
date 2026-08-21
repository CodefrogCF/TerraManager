import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';

void main() {
  late AppDatabase database;
  late BoxRepository repository;

  setUp(() {
    database = AppDatabase.test(
      NativeDatabase.memory(),
    );

    repository = BoxRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('can get a box by id', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

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
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-002',
          ),
        );

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
    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-003',
          ),
        );

    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-004',
          ),
        );

    final boxes = await repository.getAllBoxes();

    expect(boxes.length, 2);
    expect(boxes[0].qrId, 'test-box-003');
    expect(boxes[1].qrId, 'test-box-004');
  });

  test('getAllBoxes returns an empty list when no boxes exist', () async {
    final boxes = await repository.getAllBoxes();

    expect(boxes, isEmpty);
  });
}