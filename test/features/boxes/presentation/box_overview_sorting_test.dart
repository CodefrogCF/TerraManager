import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/boxes/presentation/box_overview_sorting.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';

void main() {
  Box box(int id, DateTime createdAt) {
    return Box(
      id: id,
      qrId: 'box-$id',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  test('sorts Boxes by creation time in both directions', () {
    final boxes = [
      box(1, DateTime(2026, 9, 2)),
      box(2, DateTime(2026, 9, 3)),
      box(3, DateTime(2026, 9, 1)),
    ];

    final oldestFirst = sortBoxesForOverview(
      boxes,
      BoxSortOrder.createdOldestFirst,
    );
    final newestFirst = sortBoxesForOverview(
      boxes,
      BoxSortOrder.createdNewestFirst,
    );

    expect(oldestFirst.map((box) => box.id), [3, 1, 2]);
    expect(newestFirst.map((box) => box.id), [2, 1, 3]);

    expect(boxes.map((box) => box.id), [1, 2, 3]);
  });

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
  });

  test('uses Box ids as deterministic creation-time tie breakers', () {
    final createdAt = DateTime(2026, 9, 1);
    final boxes = [box(2, createdAt), box(1, createdAt), box(3, createdAt)];

    expect(
      sortBoxesForOverview(
        boxes,
        BoxSortOrder.createdOldestFirst,
      ).map((box) => box.id),
      [1, 2, 3],
    );
    expect(
      sortBoxesForOverview(
        boxes,
        BoxSortOrder.createdNewestFirst,
      ).map((box) => box.id),
      [3, 2, 1],
    );
  });
}
