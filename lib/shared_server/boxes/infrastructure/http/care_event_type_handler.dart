import 'dart:io';

import 'package:terramanager/shared_server/boxes/application/care_event_type_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';

class CareEventTypeHandler {
  const CareEventTypeHandler(this.operations);
  final CareEventTypeOperations operations;
  Future<ApiReply> handle(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    if (path.length == 1 && method == 'GET') return operations.list();
    if (path.length == 1 && method == 'POST') {
      return operations.create(await readCollectionBody(request));
    }
    if (path.length == 2 && path[1] == 'order' && method == 'PUT') {
      return operations.reorder(await readCollectionBody(request));
    }
    if (path.length == 2 && method == 'PATCH') {
      return operations.update(path[1], await readCollectionBody(request));
    }
    return apiError(404, 'not_found', 'Unknown care type operation.');
  }
}
