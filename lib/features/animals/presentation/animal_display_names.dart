import 'package:flutter/widgets.dart';

import '../../settings/animal_name_order.dart';
import '../../settings/app_settings_controller.dart';

class AnimalDisplayNames {
  final String primary;
  final String secondary;

  const AnimalDisplayNames({required this.primary, required this.secondary});

  factory AnimalDisplayNames.fromContext(
    BuildContext context, {
    required String commonName,
    required String latinName,
  }) {
    final order =
        AppSettingsScope.maybeOf(context)?.animalNameOrder ??
        AnimalNameOrder.commonNameFirst;

    return AnimalDisplayNames.fromOrder(
      commonName: commonName,
      latinName: latinName,
      order: order,
    );
  }

  factory AnimalDisplayNames.fromOrder({
    required String commonName,
    required String latinName,
    required AnimalNameOrder order,
  }) {
    return switch (order) {
      AnimalNameOrder.commonNameFirst => AnimalDisplayNames(
        primary: commonName,
        secondary: latinName,
      ),
      AnimalNameOrder.latinNameFirst => AnimalDisplayNames(
        primary: latinName,
        secondary: commonName,
      ),
    };
  }
}
