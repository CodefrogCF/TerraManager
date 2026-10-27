import 'package:terramanager/core/database/repositories/custom_field_repository.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/application/collection_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

class CustomFieldOperations extends CollectionOperations {
  CustomFieldOperations(super.database);
  CustomFieldRepository get repository => CustomFieldRepository(database);
  Future<ApiReply> list() async => ApiReply(200, {
    'templates': (await repository.templates()).map((t) => t.toJson()).toList(),
  });
  Future<ApiReply> snapshot(CustomFieldTarget target, int id) async {
    try {
      return ApiReply(200, (await repository.snapshot(target, id)).toJson());
    } on StateError {
      return apiError(404, 'not_found', 'Record not found.');
    }
  }

  Future<ApiReply> save(ApiInput input, {String? id}) async {
    input.allow(const {
      'id',
      'target',
      'type',
      'label',
      'hidden',
      'archived',
      'revision',
    });
    try {
      final t = CustomFieldTemplate.fromJson(input.values);
      if (id != null && id != t.id) throw ArgumentError('Field ID mismatch.');
      final saved = id == null
          ? await repository.create(t)
          : await repository.update(t);
      return ApiReply(id == null ? 201 : 200, {'template': saved.toJson()});
    } on TypeError {
      throw ArgumentError('Invalid field definition.');
    }
  }
}
