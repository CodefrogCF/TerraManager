import 'package:terramanager/features/custom_fields/presentation/custom_fields.dart';

import '../../domain/food_preset.dart';

class FeedingDetailsAccess {
  const FeedingDetailsAccess({
    required this.fields,
    required this.presets,
    required this.savePreset,
  });

  final CustomFieldAccess fields;
  final Future<List<FoodPreset>> Function() presets;
  final Future<void> Function(FoodPreset, {required bool creating}) savePreset;
}
