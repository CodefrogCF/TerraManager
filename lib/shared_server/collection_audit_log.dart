import '../core/database/app_database.dart';
import 'audit_event.dart';

/// Not a Drift collection table: excluded from portable collection archives.
/// Persisted alongside collection data so mutations and audit commit together.
class CollectionAuditLog {
  const CollectionAuditLog(this.database);
  final AppDatabase database;

  Future<void> initialize() async {
    await database.customStatement(auditTableSql);
    await database.customStatement(auditIndexSql);
    await _prune();
  }

  Future<void> record(AuditEvent event) async {
    await database.customStatement(auditInsertSql, event.sqlValues);
    await _prune();
  }

  Future<void> _prune() => database.customStatement(
    'DELETE FROM shared_audit_events WHERE occurred_at < ?',
    [DateTime.now().toUtc().subtract(auditRetention).toIso8601String()],
  );
}
