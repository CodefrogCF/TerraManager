import 'package:terramanager/shared_client/administration/audit/domain/shared_audit_models.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedAuditApi on SharedApiTransport {
  Future<SharedAuditPage> auditEvents({
    String? cursor,
    String? actor,
    String? action,
    DateTime? from,
    DateTime? until,
    int limit = 20,
  }) async {
    if (sessionState?.role != 'administrator') {
      throw const SharedApiException(
        403,
        'forbidden',
        'Administrator access required.',
      );
    }
    final path = Uri(
      path: '/api/v1/admin/audit',
      queryParameters: {
        'limit': '$limit',
        'cursor': ?cursor,
        if (actor != null && actor.trim().isNotEmpty) 'actor': actor.trim(),
        'action': ?action,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (until != null) 'until': until.toUtc().toIso8601String(),
      },
    ).toString();
    final json = await requestJson('GET', path);
    try {
      return SharedAuditPage.fromJson(json);
    } catch (_) {
      throw const SharedApiException(
        200,
        'invalid_response',
        'The server returned invalid audit metadata.',
      );
    }
  }
}
