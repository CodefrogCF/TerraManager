import 'package:terramanager/core/sorting/natural_string_comparator.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';

List<Map<String, dynamic>> sortSharedBoxesForOverview(
  Iterable<Map<String, dynamic>> boxes,
  BoxSortOrder order,
) {
  final values = boxes.toList();
  values.sort((a, b) {
    final aId = recordId(a);
    final bId = recordId(b);
    if (order == BoxSortOrder.labelAscending) return aId.compareTo(bId);
    if (order == BoxSortOrder.labelDescending) return bId.compareTo(aId);
    if (order == BoxSortOrder.nameAscending ||
        order == BoxSortOrder.nameDescending) {
      final aName = ((a['name'] as String?) ?? '').trim();
      final bName = ((b['name'] as String?) ?? '').trim();
      if (aName.isEmpty && bName.isNotEmpty) return 1;
      if (bName.isEmpty && aName.isNotEmpty) return -1;
      final result = compareNaturalStrings(aName, bName);
      if (result == 0) return aId.compareTo(bId);
      return order == BoxSortOrder.nameDescending ? -result : result;
    }
    double? volume(Map<String, dynamic> box) {
      final width = box['widthCm'] as num?;
      final height = box['heightCm'] as num?;
      final depth = box['depthCm'] as num?;
      if (width == null || height == null || depth == null) return null;
      return width.toDouble() * height.toDouble() * depth.toDouble();
    }

    final aVolume = volume(a);
    final bVolume = volume(b);
    if (aVolume == null || bVolume == null) {
      if (aVolume == null && bVolume == null) return aId.compareTo(bId);
      return aVolume == null ? 1 : -1;
    }
    final result = aVolume.compareTo(bVolume);
    if (result == 0) return aId.compareTo(bId);
    return order == BoxSortOrder.volumeDescending ? -result : result;
  });
  return values;
}
