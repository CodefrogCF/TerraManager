import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_payload.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedBoxesApi on SharedApiTransport {
  Future<List<Map<String, dynamic>>> boxes() async =>
      readApiList(await requestJson('GET', '/api/v1/boxes'), 'boxes');

  Future<Map<String, dynamic>> box(int id) async =>
      readApiObject(await requestJson('GET', '/api/v1/boxes/$id'), 'box');

  Future<Map<String, dynamic>> boxByQrId(String qrId) async => readApiObject(
    await requestJson('GET', '/api/v1/boxes/qr/${Uri.encodeComponent(qrId)}'),
    'box',
  );

  Future<Map<String, dynamic>> createBox(Map<String, dynamic> values) async =>
      readApiObject(
        await requestJson('POST', '/api/v1/boxes', body: values),
        'box',
      );

  Future<Map<String, dynamic>> updateBox(
    int id,
    Map<String, dynamic> values,
    String expectedRevision,
  ) async => readApiObject(
    await requestJson(
      'PATCH',
      '/api/v1/boxes/$id',
      body: {...values, 'expectedRevision': expectedRevision},
    ),
    'box',
  );

  Future<Map<String, dynamic>> archiveBox(
    int id,
    String reason,
    String? notes,
  ) async => readApiObject(
    await requestJson(
      'POST',
      '/api/v1/boxes/$id/archive',
      body: {'reason': reason, 'archiveNotes': notes},
    ),
    'box',
  );

  Future<Map<String, dynamic>> restoreBox(int id) async => readApiObject(
    await requestJson('POST', '/api/v1/boxes/$id/restore', body: {}),
    'box',
  );

  Future<Map<String, dynamic>> duplicateBox(int id, String? name) async =>
      readApiObject(
        await requestJson(
          'POST',
          '/api/v1/boxes/$id/duplicate',
          body: {'name': name},
        ),
        'box',
      );

  Future<void> deleteBox(int id) async {
    await requestJson('DELETE', '/api/v1/boxes/$id');
  }
}
