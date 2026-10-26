import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/application/collection_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

class BoxCareOperations extends CollectionOperations {
  BoxCareOperations(super.database);
  BoxCareRepository get _repository => BoxCareRepository(database);
  Future<ApiReply> list(int boxId) async => ApiReply(200, {
    'careEvents': (await _repository.history(boxId))
        .map((e) => e.toJson())
        .toList(),
  });

  List<int> _media(ApiInput input) =>
      input.values['mediaIds'] == null ||
          (input.values['mediaIds'] is List &&
              (input.values['mediaIds'] as List).isEmpty)
      ? const []
      : input.integerList('mediaIds');

  Future<ApiReply> create(int boxId, ApiInput input) async {
    input.allow(const {'type', 'occurredAt', 'notes', 'mediaIds', 'requestId'});
    final requestId = input.string('requestId', maxLength: 64);
    final previous = await _repository.byRequestId(requestId);
    final id = await _repository.add(
      boxId: boxId,
      type: input.enumerated('type', BoxCareEventType.values),
      occurredAt: input.dateTime('occurredAt'),
      notes: input.nullableString('notes'),
      mediaIds: _media(input),
      requestId: requestId,
    );
    final event = (await _repository.history(boxId))
        .firstWhere((e) => e.id == id);
    return ApiReply(201, {
      'careEvent': event.toJson(),
    }, replayed: previous != null);
  }

  Future<ApiReply> update(int boxId, int id, ApiInput input) async {
    input.allow(const {
      'type',
      'occurredAt',
      'notes',
      'mediaIds',
      'expectedRevision',
      'expectedRequestId',
    });
    final changed = await _repository.update(
      boxId: boxId,
      id: id,
      expectedRevision: input.integer('expectedRevision'),
      expectedRequestId: input.string('expectedRequestId', maxLength: 64),
      type: input.enumerated('type', BoxCareEventType.values),
      occurredAt: input.dateTime('occurredAt'),
      notes: input.nullableString('notes'),
      mediaIds: _media(input),
    );
    if (!changed) {
      throw const ApiProblem(
        409,
        'stale_record',
        'Care event changed. Reload and review it.',
      );
    }
    final event = (await _repository.history(boxId))
        .firstWhere((e) => e.id == id);
    return ApiReply(200, {'careEvent': event.toJson()});
  }

  Future<ApiReply> delete(int boxId, int id, ApiInput input) async {
    input.allow(const {'expectedRevision', 'expectedRequestId'});
    if (!await _repository.delete(
      boxId: boxId,
      id: id,
      expectedRevision: input.integer('expectedRevision'),
      expectedRequestId: input.string('expectedRequestId', maxLength: 64),
    )) {
      throw const ApiProblem(
        409,
        'stale_record',
        'Care event changed. Reload and review it.',
      );
    }
    return const ApiReply(200, {'deleted': true});
  }
}
