import 'dart:async';
import 'dart:io';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/audit/application/audit_query.dart';
import 'package:terramanager/shared_server/audit/infrastructure/collection_audit_log.dart';
import 'package:terramanager/shared_server/collection/application/collection_operation_gate.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_response.dart';

class AuditHandler {
  const AuditHandler(this._database, this.accounts, this._gate);
  final AppDatabase _database;
  final AccountStore accounts;
  final CollectionOperationGate _gate;
  Future<void> handle(HttpRequest request) async {
    final query = AuditQuery.parse(request.uri);
    // Stay out of collection replacement transactions, just like care reads.
    if (_gate.exclusive) {
      throw const ApiProblem(
        503,
        'restore_in_progress',
        'The shared collection is temporarily unavailable.',
      );
    }
    final events = await CollectionAuditLog(_database).read(query);
    events.addAll(accounts.readAudit(query));
    await sendApiResponse(
      request.response,
      200,
      auditPage(events, query.limit),
    );
    return;
  }
}
