import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_payload.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedCareHistoryApi on SharedApiTransport {
  Future<List<Map<String, dynamic>>> weights(int animalId) async => readApiList(
    await requestJson('GET', '/api/v1/animals/$animalId/weights'),
    'weights',
  );

  Future<List<Map<String, dynamic>>> shedding(int animalId) async =>
      readApiList(
        await requestJson('GET', '/api/v1/animals/$animalId/shedding'),
        'shedding',
      );

  Future<Map<String, dynamic>> addWeight(
    int animalId,
    double grams,
    DateTime measuredAt,
  ) async => readApiObject(
    await requestJson(
      'POST',
      '/api/v1/animals/$animalId/weights',
      body: {
        'weightGrams': grams,
        'measuredAt': measuredAt.toUtc().toIso8601String(),
      },
    ),
    'weight',
  );

  Future<Map<String, dynamic>> updateWeight(
    int animalId,
    int id,
    double grams,
    DateTime measuredAt,
  ) async => readApiObject(
    await requestJson(
      'PUT',
      '/api/v1/animals/$animalId/weights/$id',
      body: {
        'weightGrams': grams,
        'measuredAt': measuredAt.toUtc().toIso8601String(),
      },
    ),
    'weight',
  );

  Future<void> deleteWeight(int animalId, int id) async {
    await requestJson('DELETE', '/api/v1/animals/$animalId/weights/$id');
  }

  Future<Map<String, dynamic>> addShedding(
    int animalId,
    DateTime shedAt,
    String? notes,
  ) async => readApiObject(
    await requestJson(
      'POST',
      '/api/v1/animals/$animalId/shedding',
      body: {'shedAt': shedAt.toUtc().toIso8601String(), 'notes': notes},
    ),
    'shedding',
  );

  Future<Map<String, dynamic>> updateShedding(
    int animalId,
    int id,
    DateTime shedAt,
    String? notes,
  ) async => readApiObject(
    await requestJson(
      'PUT',
      '/api/v1/animals/$animalId/shedding/$id',
      body: {'shedAt': shedAt.toUtc().toIso8601String(), 'notes': notes},
    ),
    'shedding',
  );

  Future<void> deleteShedding(int animalId, int id) async {
    await requestJson('DELETE', '/api/v1/animals/$animalId/shedding/$id');
  }
}
