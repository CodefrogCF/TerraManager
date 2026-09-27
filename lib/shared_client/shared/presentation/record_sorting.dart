import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';

int compareSharedDates(
  String key,
  Map<String, dynamic> first,
  Map<String, dynamic> second, {
  required bool descending,
  bool missingFirst = false,
}) {
  final a = DateTime.tryParse(first[key] as String? ?? '');
  final b = DateTime.tryParse(second[key] as String? ?? '');
  if (a == null && b != null) return missingFirst ? -1 : 1;
  if (b == null && a != null) return missingFirst ? 1 : -1;
  final result = a == null ? 0 : a.compareTo(b!);
  if (result != 0) return descending ? -result : result;
  if (a == null) return recordId(first).compareTo(recordId(second));
  return descending
      ? recordId(second).compareTo(recordId(first))
      : recordId(first).compareTo(recordId(second));
}
