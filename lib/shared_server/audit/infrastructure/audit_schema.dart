import 'package:terramanager/shared_server/audit/application/audit_query.dart'
    show auditTimeKeySql;
import 'package:terramanager/shared_server/audit/domain/audit_event.dart';

const auditTableSql =
    'CREATE TABLE IF NOT EXISTS shared_audit_events ('
    'id TEXT PRIMARY KEY, occurred_at TEXT NOT NULL, actor_id TEXT NOT NULL, '
    'actor_name TEXT NOT NULL, actor_role TEXT NOT NULL, action TEXT NOT NULL, '
    'record_type TEXT NOT NULL, record_id TEXT, outcome TEXT NOT NULL, '
    'status_code INTEGER NOT NULL)';
const auditIndexSql =
    'CREATE INDEX IF NOT EXISTS shared_audit_time '
    'ON shared_audit_events(occurred_at)';
const auditInsertSql =
    'INSERT INTO shared_audit_events '
    '(id, occurred_at, actor_id, actor_name, actor_role, action, record_type, '
    'record_id, outcome, status_code) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

const auditReadIndexSql =
    'CREATE INDEX IF NOT EXISTS shared_audit_seek '
    'ON shared_audit_events($auditTimeKeySql DESC, id DESC)';

extension AuditEventSql on AuditEvent {
  List<Object?> get sqlValues => [
    id,
    occurredAt.toIso8601String(),
    actor.id,
    actor.name,
    actor.role,
    action,
    recordType,
    recordId,
    outcome,
    statusCode,
  ];
}
