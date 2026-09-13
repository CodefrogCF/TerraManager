import '../../../core/database/app_database.dart';
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
  final firstName = _normalizedName(first.name);
  final secondName = _normalizedName(second.name);

  if (firstName == null || secondName == null) {
    if (firstName == null && secondName == null) {
      return first.id.compareTo(second.id);
    }

    return firstName == null ? 1 : -1;
  }

  final normalizedFirst = firstName.toLowerCase();
  final normalizedSecond = secondName.toLowerCase();
  final comparison = descending
      ? normalizedSecond.compareTo(normalizedFirst)
      : normalizedFirst.compareTo(normalizedSecond);

  if (comparison != 0) {
    return comparison;
  }

  final exactComparison = descending
      ? secondName.compareTo(firstName)
      : firstName.compareTo(secondName);

  if (exactComparison != 0) {
    return exactComparison;
  }

  return first.id.compareTo(second.id);
}

String? _normalizedName(String? name) {
  final trimmed = name?.trim();

  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return trimmed;
}
