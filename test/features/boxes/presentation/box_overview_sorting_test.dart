import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/boxes/presentation/box_overview_sorting.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';

void main() {
  Box box(int id, DateTime createdAt, {String? name}) {
    return Box(
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

  test('sorts named Boxes alphabetically without case sensitivity', () {
    final createdAt = DateTime(2026, 9, 1);
    final boxes = [
      box(1, createdAt, name: 'Quarantine'),
      box(2, createdAt, name: 'arboreal'),
      box(3, createdAt, name: 'Breeding'),
    ];

    final ascending = sortBoxesForOverview(boxes, BoxSortOrder.nameAscending);
    final descending = sortBoxesForOverview(boxes, BoxSortOrder.nameDescending);

    expect(ascending.map((box) => box.id), [2, 3, 1]);
    expect(descending.map((box) => box.id), [1, 3, 2]);
  });

  test('places unnamed Boxes after named Boxes in both name directions', () {
    final createdAt = DateTime(2026, 9, 1);
    final boxes = [
      box(3, createdAt),
      box(2, createdAt, name: 'Zulu'),
      box(1, createdAt, name: '  '),
      box(4, createdAt, name: 'Alpha'),
    ];

    final ascending = sortBoxesForOverview(boxes, BoxSortOrder.nameAscending);
    final descending = sortBoxesForOverview(boxes, BoxSortOrder.nameDescending);

    expect(ascending.map((box) => box.id), [4, 2, 1, 3]);
    expect(descending.map((box) => box.id), [2, 4, 1, 3]);
  });
}
