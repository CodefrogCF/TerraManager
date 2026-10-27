import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_payload.dart';

mixin SharedCustomFieldsApi on SharedApiTransport {
  Future<List<CustomFieldTemplate>> customFieldTemplates(
    CustomFieldTarget target,
  ) async =>
      (readApiList(
            await requestJson('GET', '/api/v1/custom-field-templates'),
            'templates',
          ))
          .map(CustomFieldTemplate.fromJson)
          .where((t) => t.target == target)
          .toList();
  Future<CustomFieldsSnapshot> customFields(
    CustomFieldTarget target,
    int? id,
  ) async => id == null
      ? CustomFieldsSnapshot(
          templates: await customFieldTemplates(target),
          values: const [],
        )
      : CustomFieldsSnapshot.fromJson(
          await requestJson(
            'GET',
            '/api/v1/${target == CustomFieldTarget.animal ? 'animals' : 'boxes'}/$id/custom-fields',
          ),
        );
  Future<void> saveCustomFieldTemplate(
    CustomFieldTemplate t, {
    required bool creating,
  }) async {
    await requestJson(
      creating ? 'POST' : 'PATCH',
      '/api/v1/custom-field-templates${creating ? '' : '/${t.id}'}',
      body: t.toJson(),
    );
  }
}
