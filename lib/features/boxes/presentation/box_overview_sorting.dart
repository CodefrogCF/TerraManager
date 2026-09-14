import '../../../core/database/app_database.dart';
import '../../../core/sorting/natural_string_comparator.dart';
import '../../settings/box_sort_order.dart';

List<Box> sortBoxesForOverview(Iterable<Box> boxes, BoxSortOrder sortOrder) {
  final sortedBoxes = boxes.toList();

  sortedBoxes.sort((first, second) {
    return switch (sortOrder) {
      BoxSortOrder.labelAscending => first.id.compareTo(second.id),
      BoxSortOrder.labelDescending => second.id.compareTo(first.id),
      BoxSortOrder.nameAscending => _compareNames(
        first,
        second,
        descending: false,
      ),
      BoxSortOrder.nameDescending => _compareNames(
        first,
        second,
        descending: true,
      ),
    };
  });

  return sortedBoxes;
}

int _compareNames(Box first, Box second, {required bool descending}) {
  final firstName = _displayedName(first);
  final secondName = _displayedName(second);
  final comparison = descending
      ? compareNaturalStrings(secondName, firstName)
      : compareNaturalStrings(firstName, secondName);

  if (comparison != 0) {
    return comparison;
  }

  return first.id.compareTo(second.id);
}

String _displayedName(Box box) {
  final trimmed = box.name?.trim();

  if (trimmed == null || trimmed.isEmpty) {
    return 'Box ${box.id}';
  }

  return trimmed;
}
