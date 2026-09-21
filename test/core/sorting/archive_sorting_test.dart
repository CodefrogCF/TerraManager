import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/sorting/archive_sorting.dart';
import 'package:terramanager/features/settings/archive_sort_order.dart';

void main() {
  test('archive criteria use documented defaults '
      'and reversible directions', () {
    expect(
      ArchiveSortCriterion.archivedAt.defaultOrder,
      ArchiveSortOrder.archivedNewestFirst,
    );

    expect(
      ArchiveSortCriterion.name.defaultOrder,
      ArchiveSortOrder.nameAscending,
    );

    for (final order in ArchiveSortOrder.values) {
      expect(order.reversed.reversed, order);

      expect(order.criterion, isNotNull);
    }
  });

  test('archive sorting defaults to newest '
      'timestamp with deterministic id tie', () {
    final records = [
      _Record(id: 1, name: 'One', archivedAt: DateTime(2026, 9, 1)),
      _Record(id: 2, name: 'Two', archivedAt: DateTime(2026, 9, 3)),
      _Record(id: 3, name: 'Three', archivedAt: DateTime(2026, 9, 3)),
    ];

    final sorted = sortArchivedRecords<_Record>(
      records,
      sortOrder: ArchiveSortOrder.archivedNewestFirst,
      archivedAt: (record) => record.archivedAt,
      displayName: (record) => record.name,
      id: (record) => record.id,
    );

    expect(sorted.map((record) => record.id), [3, 2, 1]);

    expect(records.map((record) => record.id), [1, 2, 3]);
  });

  test('archive sorting uses natural names '
      'in both directions', () {
    final records = [
      _Record(id: 10, name: 'Animal 10', archivedAt: DateTime(2026, 9, 1)),
      _Record(id: 2, name: 'Animal 2', archivedAt: DateTime(2026, 9, 2)),
      _Record(id: 1, name: 'Animal 1', archivedAt: DateTime(2026, 9, 3)),
    ];

    expect(
      sortArchivedRecords<_Record>(
        records,
        sortOrder: ArchiveSortOrder.nameAscending,
        archivedAt: (record) => record.archivedAt,
        displayName: (record) => record.name,
        id: (record) => record.id,
      ).map((record) => record.id),
      [1, 2, 10],
    );

    expect(
      sortArchivedRecords<_Record>(
        records,
        sortOrder: ArchiveSortOrder.nameDescending,
        archivedAt: (record) => record.archivedAt,
        displayName: (record) => record.name,
        id: (record) => record.id,
      ).map((record) => record.id),
      [10, 2, 1],
    );
  });
}

class _Record {
  const _Record({
    required this.id,
    required this.name,
    required this.archivedAt,
  });

  final int id;
  final String name;
  final DateTime? archivedAt;
}
