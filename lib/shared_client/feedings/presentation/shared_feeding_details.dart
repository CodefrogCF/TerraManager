import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/features/feedings/presentation/widgets/feeding_details_access.dart';
import 'package:terramanager/shared_client/custom_fields/presentation/shared_custom_fields.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

FeedingDetailsAccess sharedFeedingDetails(SharedApiClient api) =>
    FeedingDetailsAccess(
      fields: sharedCustomFields(api, CustomFieldTarget.feeding),
      presets: api.foodPresets,
      savePreset: api.saveFoodPreset,
    );
