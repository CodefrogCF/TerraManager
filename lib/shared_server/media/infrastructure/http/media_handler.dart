import 'dart:async';
import 'dart:io';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/shared_server/media/application/media_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';

class MediaHandler {
  const MediaHandler(this.operations);
  final MediaOperations operations;
  Future<ApiReply> handle(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    final media = operations;
    if (path.length == 2 && method == 'GET') {
      final asset = await media.getMediaById(parseRecordId(path[1]));
      if (asset == null) return apiError(404, 'not_found', 'Media not found.');
      return ApiReply.bytes(200, asset.data, asset.mimeType);
    }
    return apiError(404, 'not_found', 'Unknown Media operation.');
  }

  Future<ApiReply> boxPictures(
    List<String> path,
    String method,
    HttpRequest request,
    Box box,
  ) async {
    if (path.length == 3 && method == 'GET') {
      return operations.boxList(box);
    }
    if (box.status != BoxStatus.active) {
      return apiError(409, 'conflict', 'Box is not active.');
    }
    if (path.length == 3 && method == 'POST') {
      final input = await readCollectionBody(
        request,
        maxBytes: 12 * 1024 * 1024,
      );
      return operations.boxCreate(
        box,
        input,
        request.headers.value('Idempotency-Key'),
      );
    }
    if (path.length < 4) {
      return apiError(404, 'not_found', 'Unknown Box picture operation.');
    }
    final mediaId = parseRecordId(path[3]);
    if (path.length == 5 && path[4] == 'primary' && method == 'POST') {
      return operations.boxPrimary(box, mediaId);
    }
    if (path.length == 4 && method == 'DELETE') {
      return operations.boxDelete(box, mediaId);
    }
    return apiError(404, 'not_found', 'Unknown Box picture operation.');
  }

  Future<ApiReply> animalPictures(
    List<String> path,
    String method,
    HttpRequest request,
    Animal animal,
  ) async {
    if (path.length == 3 && method == 'GET') {
      return operations.animalList(animal);
    }
    if (animal.status != AnimalStatus.active) {
      return apiError(409, 'conflict', 'Animal is not active.');
    }
    if (path.length == 3 && method == 'POST') {
      final input = await readCollectionBody(
        request,
        maxBytes: 12 * 1024 * 1024,
      );
      return operations.animalCreate(
        animal,
        input,
        request.headers.value('Idempotency-Key'),
      );
    }
    if (path.length < 4) {
      return apiError(404, 'not_found', 'Unknown Animal picture operation.');
    }
    final mediaId = parseRecordId(path[3]);
    if (path.length == 5 && path[4] == 'primary' && method == 'POST') {
      return operations.animalPrimary(animal, mediaId);
    }
    if (path.length == 4 && method == 'DELETE') {
      return operations.animalDelete(animal, mediaId);
    }
    return apiError(404, 'not_found', 'Unknown Animal picture operation.');
  }
}
