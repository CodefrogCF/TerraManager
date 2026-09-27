import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_payload.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedAnimalsApi on SharedApiTransport {
  Future<List<Map<String, dynamic>>> animals() async =>
      readApiList(await requestJson('GET', '/api/v1/animals'), 'animals');

  Future<Map<String, dynamic>> animal(int id) async =>
      readApiObject(await requestJson('GET', '/api/v1/animals/$id'), 'animal');

  Future<Map<String, dynamic>> createAnimal(
    Map<String, dynamic> values,
  ) async => readApiObject(
    await requestJson('POST', '/api/v1/animals', body: values),
    'animal',
  );

  Future<Map<String, dynamic>> updateAnimal(
    int id,
    Map<String, dynamic> values,
    String expectedRevision,
  ) async => readApiObject(
    await requestJson(
      'PUT',
      '/api/v1/animals/$id',
      body: {...values, 'expectedRevision': expectedRevision},
    ),
    'animal',
  );

  Future<Map<String, dynamic>> rehouseAnimal(
    int id,
    int boxId,
    String expectedRevision,
  ) async => readApiObject(
    await requestJson(
      'POST',
      '/api/v1/animals/$id/move',
      body: {'boxId': boxId, 'expectedRevision': expectedRevision},
    ),
    'animal',
  );

  Future<Map<String, dynamic>> archiveAnimal(
    int id,
    String reason,
    String? notes,
  ) async => readApiObject(
    await requestJson(
      'POST',
      '/api/v1/animals/$id/archive',
      body: {'reason': reason, 'archiveNotes': notes},
    ),
    'animal',
  );

  Future<Map<String, dynamic>> restoreAnimal(int id, int boxId) async =>
      readApiObject(
        await requestJson(
          'POST',
          '/api/v1/animals/$id/restore',
          body: {'boxId': boxId},
        ),
        'animal',
      );

  Future<Map<String, dynamic>> duplicateAnimal(
    int id,
    int boxId,
    String commonName,
  ) async => readApiObject(
    await requestJson(
      'POST',
      '/api/v1/animals/$id/duplicate',
      body: {'boxId': boxId, 'commonName': commonName},
    ),
    'animal',
  );

  Future<void> deleteAnimal(int id) async {
    await requestJson('DELETE', '/api/v1/animals/$id');
  }
}
