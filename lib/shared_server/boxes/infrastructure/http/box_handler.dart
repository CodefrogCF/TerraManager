import 'dart:async';
import 'dart:io';

import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/shared_server/boxes/application/box_operations.dart';
import 'package:terramanager/shared_server/media/infrastructure/http/media_handler.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';
import 'package:terramanager/shared_server/shared/infrastructure/serialization/api_models.dart';

class BoxHandler {
  const BoxHandler({required this.operations, required this.pictures});
  final BoxOperations operations;
  final MediaHandler pictures;
  Future<ApiReply> handle(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    final boxes = operations;
    if (path.length == 1 && method == 'GET') {
      return operations.list();
    }
    if (path.length == 1 && method == 'POST') {
      final input = await readCollectionBody(request);
      return operations.create(input);
    }
    if (path.length == 3 && path[1] == 'qr' && method == 'GET') {
      return operations.findByQrId(path[2]);
    }
    if (path.length < 2) {
      return apiError(404, 'not_found', 'Unknown Box operation.');
    }
    final id = parseRecordId(path[1]);
    final existing = await boxes.getBoxById(id);
    if (existing == null) return apiError(404, 'not_found', 'Box not found.');
    if (path.length == 2 && method == 'GET') {
      return ApiReply(200, {'box': boxJson(existing)});
    }
    if (path.length == 3 && path[2] == 'duplicate' && method == 'POST') {
      final input = await readCollectionBody(request);
      return operations.duplicate(id, input);
    }
    if (path.length >= 3 && path[2] == 'pictures') {
      return pictures.boxPictures(path, method, request, existing);
    }
    if (path.length == 2 && method == 'PATCH') {
      if (existing.status != BoxStatus.active) {
        return apiError(409, 'conflict', 'Only active Boxes can be edited.');
      }
      final input = await readCollectionBody(request);
      return operations.update(id, existing, input);
    }
    if (path.length == 3 && path[2] == 'archive' && method == 'POST') {
      final input = await readCollectionBody(request);
      return operations.archive(id, input);
    }
    if (path.length == 3 && path[2] == 'restore' && method == 'POST') {
      return operations.restore(id);
    }
    if (path.length == 2 && method == 'DELETE') {
      return operations.delete(id);
    }
    return apiError(404, 'not_found', 'Unknown Box operation.');
  }
}
