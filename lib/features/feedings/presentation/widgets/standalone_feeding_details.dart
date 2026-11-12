import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/food_preset_repository.dart';
import 'package:terramanager/features/custom_fields/presentation/standalone_custom_fields.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';

import 'feeding_details_access.dart';

FeedingDetailsAccess standaloneFeedingDetails(AppDatabase database) {
  final presets = FoodPresetRepository(database);
  return FeedingDetailsAccess(
    fields: standaloneCustomFields(database, CustomFieldTarget.feeding),
    presets: presets.all,
    savePreset: (preset, {required creating}) async {
      await presets.save(preset, creating: creating);
    },
  );
}
