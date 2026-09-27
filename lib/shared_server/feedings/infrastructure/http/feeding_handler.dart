import 'dart:async';
import 'dart:io';

import 'package:terramanager/shared_server/feedings/application/feeding_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';
import 'package:terramanager/shared_server/shared/infrastructure/serialization/api_models.dart';

class FeedingHandler {
  const FeedingHandler({required this.operations});
  final FeedingOperations operations;
  Future<ApiReply> handle(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    final feedings = operations;
    if (path.length == 1 && method == 'POST') {
      final input = await readCollectionBody(request);
      final requestId = request.headers.value('Idempotency-Key');

      return operations.create(input, requestId);
    }
    if (path.length != 2) {
      return apiError(404, 'not_found', 'Unknown Feeding operation.');
    }
    final id = parseRecordId(path[1]);
    final existing = await feedings.getFeedingById(id);
    if (existing == null) {
      return apiError(404, 'not_found', 'Feeding not found.');
    }
    if (method == 'GET') {
      return ApiReply(200, {'feeding': feedingJson(existing)});
    }
    if (method == 'PUT') {
      final input = await readCollectionBody(request);
      return operations.update(id, input);
    }
    if (method == 'DELETE') {
      return operations.delete(id);
    }
    return apiError(404, 'not_found', 'Unknown Feeding operation.');
  }
}
