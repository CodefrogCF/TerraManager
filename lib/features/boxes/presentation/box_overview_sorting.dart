import '../../../core/database/app_database.dart';
import '../../settings/box_sort_order.dart';

List<Box> sortBoxesForOverview(Iterable<Box> boxes, BoxSortOrder sortOrder) {
  final sortedBoxes = boxes.toList();

  sortedBoxes.sort((first, second) {
    return switch (sortOrder) {
      BoxSortOrder.labelAscending => first.id.compareTo(second.id),
      BoxSortOrder.labelDescending => second.id.compareTo(first.id),
    };
  });

  return sortedBoxes;
}
