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
      BoxSortOrder.volumeAscending => _compareVolume(
        first,
        second,
        descending: false,
      ),
      BoxSortOrder.volumeDescending => _compareVolume(
        first,
        second,
        descending: true,
      ),
    };
  });

  return sortedBoxes;
}

int _compareNames(Box first, Box second, {required bool descending}) {
  final firstName = _name(first);
  final secondName = _name(second);

  if (firstName == null || secondName == null) {
    if (firstName == null && secondName == null) {
      return first.id.compareTo(second.id);
    }

    return firstName == null ? 1 : -1;
  }

  final comparison = descending
      ? compareNaturalStrings(secondName, firstName)
      : compareNaturalStrings(firstName, secondName);

  if (comparison != 0) {
    return comparison;
  }

  return first.id.compareTo(second.id);
}

String? _name(Box box) {
  final trimmed = box.name?.trim();

  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return trimmed;
}

int _compareVolume(Box first, Box second, {required bool descending}) {
  final firstVolume = _volume(first);
  final secondVolume = _volume(second);

  if (firstVolume == null || secondVolume == null) {
    if (firstVolume == null && secondVolume == null) {
      return first.id.compareTo(second.id);
    }

    return firstVolume == null ? 1 : -1;
  }

  final comparison = descending
      ? secondVolume.compareTo(firstVolume)
      : firstVolume.compareTo(secondVolume);

  return comparison != 0 ? comparison : first.id.compareTo(second.id);
}

double? _volume(Box box) {
  final width = box.widthCm;
  final height = box.heightCm;
  final depth = box.depthCm;

  if (width == null || height == null || depth == null) {
    return null;
  }

  return width * height * depth;
}
