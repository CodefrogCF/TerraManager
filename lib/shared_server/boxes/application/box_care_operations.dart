import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/core/database/repositories/box_care_reminder_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/features/boxes/domain/box_care_reminder.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/application/collection_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

class BoxCareOperations extends CollectionOperations {
  BoxCareOperations(super.database);
  BoxCareRepository get _repository => BoxCareRepository(database);
  BoxCareReminderRepository get _reminders =>
      BoxCareReminderRepository(database);

  Future<ApiReply> list(int boxId) => database.transaction(
    () async => ApiReply(200, {
      'careEvents': (await _repository.history(boxId))
          .map((e) => e.toJson())
          .toList(),
      'careReminders': (await _reminders.forBox(boxId))
          .map((r) => r.toJson())
          .toList(),
    }),
  );

  Future<ApiReply> saveReminder(
    int boxId,
    String typeKey,
    ApiInput input,
  ) async {
    input.allow(const {'dueOn', 'intervalDays', 'expectedRevision'});
    if (!input.values.containsKey('dueOn')) {
      throw const ApiProblem(400, 'invalid_data', 'dueOn is required.');
    }
    await _reminders.save(
      boxId: boxId,
      typeKey: typeKey,
      dueOn: _calendarDate(input, 'dueOn'),
      intervalDays: input.nullableInteger('intervalDays'),
      expectedRevision: input.nullableString('expectedRevision', maxLength: 36),
    );
    return const ApiReply(200, {'saved': true});
  }

  Future<ApiReply> create(int boxId, ApiInput input) async {
    input.allow(const {
      'type',
      'customTypeId',
      'occurredAt',
      'occurredOn',
      'notes',
      'requestId',
    });
    final requestId = input.string('requestId', maxLength: 64);
    final result = await _repository.addWithResult(
      boxId: boxId,
      type: input.enumerated('type', BoxCareEventType.values),
      customTypeId: input.nullableString('customTypeId', maxLength: 36),
      occurredAt: input.dateTime('occurredAt'),
      occurredOn: _calendarDate(input, 'occurredOn'),
      notes: input.nullableString('notes'),
      requestId: requestId,
    );
    final event = (await _repository.byRequestId(requestId))!;
    return ApiReply(201, {
      'careEvent': event.toJson(),
      if (result.reminderChanged) 'reminderChanged': true,
    }, replayed: result.replayed);
  }

  DateTime? _calendarDate(ApiInput input, String key) {
    final value = input.values[key];
    if (value == null) return null;
    if (value is String) {
      try {
        return BoxCareReminder.parseDay(value);
      } on FormatException {
        // Report invalid dates through the standard API validation response.
      }
    }
    throw ApiProblem(400, 'invalid_data', '$key must be a calendar date.');
  }

  Future<ApiReply> update(int boxId, int id, ApiInput input) async {
    input.allow(const {
      'type',
      'customTypeId',
      'occurredAt',
      'notes',
      'expectedRevision',
      'expectedRequestId',
    });
    final changed = await _repository.update(
      boxId: boxId,
      id: id,
      expectedRevision: input.integer('expectedRevision'),
      expectedRequestId: input.string('expectedRequestId', maxLength: 64),
      type: input.enumerated('type', BoxCareEventType.values),
      customTypeId: input.nullableString('customTypeId', maxLength: 36),
      occurredAt: input.dateTime('occurredAt'),
      notes: input.nullableString('notes'),
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
