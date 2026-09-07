import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/animals/presentation/animal_display_names.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';

void main() {
  test('common name can be displayed first', () {
    final names = AnimalDisplayNames.fromOrder(
      commonName: 'Corn Snake',
      latinName: 'Pantherophis guttatus',
      order: AnimalNameOrder.commonNameFirst,
    );

    expect(names.primary, 'Corn Snake');
    expect(names.secondary, 'Pantherophis guttatus');
  });

  test('Latin name can be displayed first', () {
    final names = AnimalDisplayNames.fromOrder(
      commonName: 'Corn Snake',
      latinName: 'Pantherophis guttatus',
      order: AnimalNameOrder.latinNameFirst,
    );

    expect(names.primary, 'Pantherophis guttatus');
    expect(names.secondary, 'Corn Snake');
  });
}
