import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_payload.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedMediaApi on SharedApiTransport {
  Future<int> uploadMedia(
    String fileName,
    String mimeType,
    Uint8List bytes,
  ) async {
    final response = await requestJson(
      'POST',
      '/api/v1/media',
      body: {
        'fileName': fileName,
        'mimeType': mimeType,
        'dataBase64': base64Encode(bytes),
      },
    );
    final id = response['id'];
    if (id is int) return id;
    throw const SharedApiException(
      200,
      'invalid_response',
      'The server returned an invalid media ID.',
    );
  }

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
    Uint8List bytes,
  ) async => readApiObject(
    await requestJson(
      'POST',
      '/api/v1/$kind/$recordId/pictures',
      body: {
        'fileName': fileName,
        'mimeType': mimeType,
        'dataBase64': base64Encode(bytes),
      },
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
