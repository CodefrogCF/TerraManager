import 'dart:io';

import 'package:terramanager/shared_server/custom_fields/application/custom_field_operations.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';

class CustomFieldHandler {
  const CustomFieldHandler(this.operations);
  final CustomFieldOperations operations;
  Future<ApiReply> handle(
    List<String> path,
    String method,
    HttpRequest request,
  ) async {
    if (path.length == 1 && method == 'GET') return operations.list();
    if (path.length == 1 && method == 'POST') {
      return operations.save(await readCollectionBody(request));
    }
    if (path.length == 2 && method == 'PATCH') {
      return operations.save(await readCollectionBody(request), id: path[1]);
    }
    return apiError(404, 'not_found', 'Unknown field operation.');
  }
}
