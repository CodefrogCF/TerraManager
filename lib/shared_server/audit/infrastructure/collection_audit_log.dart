import 'package:drift/drift.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/audit/application/audit_query.dart';
import 'package:terramanager/shared_server/audit/domain/audit_event.dart';
import 'package:terramanager/shared_server/audit/infrastructure/audit_schema.dart';

/// Not a Drift collection table: excluded from portable collection archives.
/// Persisted alongside collection data so mutations and audit commit together.
class CollectionAuditLog {
  const CollectionAuditLog(this.database);
  final AppDatabase database;

  Future<void> initialize() async {
    await database.customStatement(auditTableSql);
    await database.customStatement(auditIndexSql);
    await database.customStatement(auditReadIndexSql);
    await _prune();
  }

  Future<void> record(AuditEvent event) async {
    await database.customStatement(auditInsertSql, event.sqlValues);
    await _prune();
  }

  Future<List<Map<String, Object?>>> read(AuditQuery query) async => [
    for (final row
        in await database
            .customSelect(
              query.sql,
              variables: [
                for (final value in query.values('collection')) Variable(value),
              ],
            )
            .get())
      auditMetadata(row.data, 'collection'),
  ];

  Future<void> _prune() => database.customStatement(
    'DELETE FROM shared_audit_events WHERE occurred_at < ?',
    [DateTime.now().toUtc().subtract(auditRetention).toIso8601String()],
  );
}
