import 'package:terramanager/core/database/repositories/care_event_type_repository.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/application/collection_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

class CareEventTypeOperations extends CollectionOperations {
  CareEventTypeOperations(super.database);
  CareEventTypeRepository get _repository => CareEventTypeRepository(database);
  String _label(ApiInput input) {
    input.string('label', maxLength: 80);
    return input.values['label'] as String;
  }

  Future<ApiReply> list() async => ApiReply(200, {
    'careEventTypes': (await _repository.all()).map((e) => e.toJson()).toList(),
  });
  Future<ApiReply> create(ApiInput input) async {
    input.allow(const {'id', 'label'});
    final id = input.string('id', maxLength: 36);
    final previous = await _repository.byId(id);
    final definition = await _repository.create(id, _label(input));
    return ApiReply(201, {
      'careEventType': definition.toJson(),
    }, replayed: previous != null);
  }

  Future<ApiReply> update(String id, ApiInput input) async {
    input.allow(const {'label', 'archived', 'expectedRevision'});
    final definition = await _repository.update(
      id: id,
      label: _label(input),
      archived: input.boolean('archived'),
      expectedRevision: input.integer('expectedRevision'),
    );
    return ApiReply(200, {'careEventType': definition.toJson()});
  }

  Future<ApiReply> reorder(ApiInput input) async {
    input.allow(const {'order'});
    final raw = input.values['order'];
    if (raw is! List) {
      throw const ApiProblem(400, 'invalid_data', 'Expected care type order.');
    }
    final order = <({String id, int revision})>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) {
        throw const ApiProblem(400, 'invalid_data', 'Invalid care type order.');
      }
      final item = ApiInput(entry)..allow(const {'id', 'revision'});
      order.add((
        id: item.string('id', maxLength: 36),
        revision: item.integer('revision'),
      ));
    }
    await _repository.reorder(order);
    return list();
  }
}
