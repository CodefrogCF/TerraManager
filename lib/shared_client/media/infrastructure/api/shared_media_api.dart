import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_payload.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedMediaApi on SharedApiTransport {
  Future<List<Map<String, dynamic>>> pictures(
    String kind,
    int recordId,
  ) async => readApiList(
    await requestJson('GET', '/api/v1/$kind/$recordId/pictures'),
    'pictures',
  );

  Future<Map<String, dynamic>> addPicture(
    String kind,
    int recordId,
    String fileName,
    String mimeType,
    Uint8List bytes, {
    String? requestId,
  }) async => readApiObject(
    await requestJson(
      'POST',
      '/api/v1/$kind/$recordId/pictures',
      body: {
        'fileName': fileName,
        'mimeType': mimeType,
        'dataBase64': base64Encode(bytes),
      },
      extraHeaders: {'Idempotency-Key': requestId ?? const Uuid().v4()},
      timeout: const Duration(minutes: 5),
    ),
    'picture',
  );

  Future<void> removePicture(String kind, int recordId, int mediaId) async {
    await requestJson('DELETE', '/api/v1/$kind/$recordId/pictures/$mediaId');
  }

  Future<void> setPrimaryPicture(String kind, int recordId, int mediaId) async {
    await requestJson(
      'POST',
      '/api/v1/$kind/$recordId/pictures/$mediaId/primary',
      body: {},
    );
  }

  Uri mediaUrl(int mediaId) => apiUrl('/api/v1/media/$mediaId');

  Future<Uint8List> mediaBytes(int mediaId) async => (await requestBinary(
    'GET',
    '/api/v1/media/$mediaId',
    timeout: const Duration(seconds: 15),
    extraHeaders: {'Accept': 'image/*'},
  )).bodyBytes;
}
