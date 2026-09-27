import 'dart:async';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/backup/application/validated_backup.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/audit/domain/audit_event.dart';
import 'package:terramanager/shared_server/audit/infrastructure/collection_audit_log.dart';
import 'package:terramanager/shared_server/backups/application/shared_portable_backups.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

class SharedBackupOperations {
  const SharedBackupOperations(this._database, this._backups);
  final AppDatabase _database;
  final SharedPortableBackups _backups;
  Future<ApiReply> restore(ValidatedBackup validated, CareAccount actor) async {
    final mediaCount = await _database.transaction(() async {
      final count = await _backups.restore(validated);
      await CollectionAuditLog(_database).record(
        AuditEvent(
          actor: actor.auditActor,
          action: 'collection.restore',
          recordType: 'collection',
          recordId: null,
          outcome: 'success',
          statusCode: 200,
        ),
      );
      return count;
    });
    return ApiReply(200, {
      'restored': true,
      'boxes': validated.boxCount,
      'animals': validated.animalCount,
      'feedings': validated.feedingEventCount,
      'media': mediaCount,
    });
  }
}
