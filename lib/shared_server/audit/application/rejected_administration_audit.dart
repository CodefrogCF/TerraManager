import 'dart:async';

import 'package:sqlite3/sqlite3.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/backup/application/backup_validation_exception.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/audit/domain/audit_event.dart';
import 'package:terramanager/shared_server/audit/infrastructure/collection_audit_log.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

class RejectedAdministrationAudit {
  const RejectedAdministrationAudit(this._database, this.accounts);
  final AppDatabase _database;
  final AccountStore accounts;
  Future<void> record(
    String method,
    List<String> parts,
    CareAccount actor,
    Object error,
  ) async {
    if (!const {'GET', 'HEAD', 'OPTIONS'}.contains(method)) {
      final status = error is ApiProblem
          ? error.status
          : error is BackupValidationException || error is FormatException
          ? 400
          : error is StateError ||
                (error is SqliteException && error.extendedResultCode == 2067)
          ? 409
          : 500;
      if (parts.length >= 4 && parts[3] == 'accounts') {
        accounts.recordRejectedAdministration(
          actor,
          method == 'POST'
              ? 'account.create'
              : method == 'DELETE'
              ? 'account.delete'
              : 'account.update',
          parts.length == 5 ? int.tryParse(parts[4]) : null,
          status,
        );
      } else if (parts.length == 5 &&
          parts[3] == 'backups' &&
          parts[4] == 'restore') {
        await CollectionAuditLog(_database).record(
          AuditEvent(
            actor: actor.auditActor,
            action: 'collection.restore',
            recordType: 'collection',
            recordId: null,
            outcome: 'rejected',
            statusCode: status,
          ),
        );
      }
    }
  }
}
