import '../../../core/database/app_database.dart';
import '../../settings/box_sort_order.dart';

List<Box> sortBoxesForOverview(Iterable<Box> boxes, BoxSortOrder sortOrder) {
  final sortedBoxes = boxes.toList();

  sortedBoxes.sort((first, second) {
    return switch (sortOrder) {
      BoxSortOrder.createdOldestFirst => _compareCreated(
        first,
        second,
        newestFirst: false,
      ),
      BoxSortOrder.createdNewestFirst => _compareCreated(
        first,
        second,
        newestFirst: true,
      ),
      BoxSortOrder.labelAscending => first.id.compareTo(second.id),
      BoxSortOrder.labelDescending => second.id.compareTo(first.id),
    };
  });

  return sortedBoxes;
}

int _compareCreated(Box first, Box second, {required bool newestFirst}) {
  final dateComparison = newestFirst
      ? second.createdAt.compareTo(first.createdAt)
      : first.createdAt.compareTo(second.createdAt);

  if (dateComparison != 0) {
    return dateComparison;
  }

  return newestFirst
      ? second.id.compareTo(first.id)
      : first.id.compareTo(second.id);
}
