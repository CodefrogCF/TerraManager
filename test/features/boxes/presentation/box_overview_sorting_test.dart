import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/enums/box_status.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/boxes/presentation/box_overview_sorting.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';

void main() {
  Box box(int id, DateTime createdAt, {String? name}) {
    return Box(
      status: BoxStatus.active,
      id: id,
      qrId: 'box-$id',
      name: name,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  test('sorts natural Box labels numerically in both directions', () {
    final createdAt = DateTime(2026, 9, 1);
    final boxes = [box(10, createdAt), box(2, createdAt), box(1, createdAt)];

    final ascending = sortBoxesForOverview(boxes, BoxSortOrder.labelAscending);
    final descending = sortBoxesForOverview(
      boxes,
      BoxSortOrder.labelDescending,
    );

    expect(ascending.map((box) => box.id), [1, 2, 10]);
    expect(descending.map((box) => box.id), [10, 2, 1]);

    expect(boxes.map((box) => box.id), [10, 2, 1]);
  });

  test('sorts named Boxes naturally without case sensitivity', () {
    final createdAt = DateTime(2026, 9, 1);
    final boxes = [
      box(1, createdAt, name: 'Habitat 10'),
      box(2, createdAt, name: 'habitat 2'),
      box(3, createdAt, name: 'Habitat 1'),
    ];

    final ascending = sortBoxesForOverview(boxes, BoxSortOrder.nameAscending);
    final descending = sortBoxesForOverview(boxes, BoxSortOrder.nameDescending);

    expect(ascending.map((box) => box.id), [3, 2, 1]);
    expect(descending.map((box) => box.id), [1, 2, 3]);
  });

  test('sorts unnamed Boxes by their displayed fallback labels', () {
    final createdAt = DateTime(2026, 9, 1);
    final boxes = [
      box(12, createdAt),
      box(3, createdAt, name: 'Alpha'),
      box(2, createdAt, name: '  '),
      box(1, createdAt, name: 'Zulu'),
    ];

    final ascending = sortBoxesForOverview(boxes, BoxSortOrder.nameAscending);
    final descending = sortBoxesForOverview(boxes, BoxSortOrder.nameDescending);

    expect(ascending.map((box) => box.id), [3, 2, 12, 1]);
    expect(descending.map((box) => box.id), [1, 12, 2, 3]);
  });

  test('uses the Box id as a stable fallback for equal names', () {
    final createdAt = DateTime(2026, 9, 1);
    final boxes = [
      box(3, createdAt, name: 'Habitat'),
      box(1, createdAt, name: 'Habitat'),
      box(2, createdAt, name: 'Habitat'),
    ];

    final ascending = sortBoxesForOverview(boxes, BoxSortOrder.nameAscending);
    final descending = sortBoxesForOverview(boxes, BoxSortOrder.nameDescending);

    expect(ascending.map((box) => box.id), [1, 2, 3]);
    expect(descending.map((box) => box.id), [1, 2, 3]);
  });
}
