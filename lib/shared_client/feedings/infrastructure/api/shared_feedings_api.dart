import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_payload.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';
import 'package:uuid/uuid.dart';

mixin SharedFeedingsApi on SharedApiTransport {
  Future<List<Map<String, dynamic>>> reminders() async =>
      readApiList(await requestJson('GET', '/api/v1/reminders'), 'reminders');

  Future<Map<String, dynamic>> updateFeedingReminder(
    int animalId, {
    required String expectedRevision,
    required int? intervalDays,
    required DateTime? baseline,
    int? weekdays,
    int? minuteOfDay,
    String? timeZone,
  }) async => readApiObject(
    await requestJson(
      'PUT',
      '/api/v1/animals/$animalId/feeding-reminder',
      body: {
        'expectedRevision': expectedRevision,
        'intervalDays': intervalDays,
        'baseline': baseline?.toUtc().toIso8601String(),
        'weekdays': weekdays,
        'minuteOfDay': minuteOfDay,
        'timeZone': timeZone,
      },
    ),
    'animal',
  );

  Future<List<Map<String, dynamic>>> feedings(int animalId) async =>
      readApiList(
        await requestJson('GET', '/api/v1/animals/$animalId/feedings'),
        'feedings',
      );

  Future<Map<String, dynamic>> createFeeding(
    int animalId,
    DateTime fedAt,
    String? notes, {
    String? requestId,
  }) async => (await createFeedings(
    animalIds: [animalId],
    fedAt: fedAt,
    notes: notes,
    requestId: requestId,
  )).single;

  Future<List<Map<String, dynamic>>> createFeedings({
    required List<int> animalIds,
    required DateTime fedAt,
    required String? notes,
    int? boxId,
    String? requestId,
  }) async {
    final body = <String, dynamic>{
      'animalIds': animalIds,
      'fedAt': fedAt.toUtc().toIso8601String(),
      'notes': notes,
    };
    if (boxId != null) {
      body['boxId'] = boxId;
    }
    return readApiList(
      await requestJson(
        'POST',
        '/api/v1/feedings',
        body: body,
        extraHeaders: {'Idempotency-Key': requestId ?? const Uuid().v4()},
      ),
      'feedings',
    );
  }

  Future<Map<String, dynamic>> updateFeeding(
    int id,
    DateTime fedAt,
    String? notes,
  ) async => readApiObject(
    await requestJson(
      'PUT',
      '/api/v1/feedings/$id',
      body: {'fedAt': fedAt.toUtc().toIso8601String(), 'notes': notes},
    ),
    'feeding',
  );

  Future<void> deleteFeeding(int id) async {
    await requestJson('DELETE', '/api/v1/feedings/$id');
  }
}
