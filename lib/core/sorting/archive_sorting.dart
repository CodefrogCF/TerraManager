import '../../features/settings/archive_sort_order.dart';
import 'natural_string_comparator.dart';

List<T> sortArchivedRecords<T>(
  Iterable<T> records, {
  required ArchiveSortOrder sortOrder,
  required DateTime? Function(T record) archivedAt,
  required String Function(T record) displayName,
  required int Function(T record) id,
}) {
  final sorted = records.toList();

  sorted.sort((first, second) {
    final primaryComparison = switch (sortOrder) {
      ArchiveSortOrder.archivedNewestFirst => _compareArchiveDates(
        archivedAt(first),
        archivedAt(second),
        newestFirst: true,
      ),

      ArchiveSortOrder.archivedOldestFirst => _compareArchiveDates(
        archivedAt(first),
        archivedAt(second),
        newestFirst: false,
      ),

      ArchiveSortOrder.nameAscending => compareNaturalStrings(
        displayName(first),
        displayName(second),
      ),

      ArchiveSortOrder.nameDescending => compareNaturalStrings(
        displayName(second),
        displayName(first),
      ),
    };

    if (primaryComparison != 0) {
      return primaryComparison;
    }

    return switch (sortOrder) {
      ArchiveSortOrder.archivedNewestFirst => id(second).compareTo(id(first)),

      ArchiveSortOrder.archivedOldestFirst => id(first).compareTo(id(second)),

      ArchiveSortOrder.nameAscending ||
      ArchiveSortOrder.nameDescending => id(first).compareTo(id(second)),
    };
  });

  return sorted;
}

int _compareArchiveDates(
  DateTime? first,
  DateTime? second, {
  required bool newestFirst,
}) {
  if (first == null && second == null) {
    return 0;
  }

  // Defensive fallback for malformed legacy records:
  // missing archive timestamps always remain last.
  if (first == null) {
    return 1;
  }

  if (second == null) {
    return -1;
  }

  return newestFirst ? second.compareTo(first) : first.compareTo(second);
}
