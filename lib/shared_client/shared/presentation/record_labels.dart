import 'package:terramanager/features/settings/animal_name_order.dart';

int recordId(Map<String, dynamic> record) => record['id'] as int;

String boxLabel(Map<String, dynamic> box) {
  final name = (box['name'] as String?)?.trim();
  return name == null || name.isEmpty
      ? 'Box ${recordId(box)}'
      : '$name · Box ${recordId(box)}';
}

String animalLabel(
  Map<String, dynamic> animal, {
  AnimalNameOrder order = AnimalNameOrder.commonNameFirst,
}) {
  final common = (animal['commonName'] as String?)?.trim() ?? '';
  final latin = (animal['latinName'] as String?)?.trim() ?? '';
  if (order == AnimalNameOrder.latinNameFirst) {
    return latin.isNotEmpty ? latin : common;
  }
  return common.isNotEmpty ? common : latin;
}
