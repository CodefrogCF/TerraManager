import 'package:uuid/uuid.dart';

/// Server-owned metadata. Never pass request bodies, headers or notes here.
class AuditActor {
  const AuditActor(this.id, this.name, this.role);
  final String id;
  final String name;
  final String role;
}

class AuditEvent {
  AuditEvent({
    required this.actor,
    required this.action,
    required this.recordType,
    required this.recordId,
    required this.outcome,
    required this.statusCode,
    DateTime? occurredAt,
  }) : id = const Uuid().v4(),
       occurredAt = (occurredAt ?? DateTime.now()).toUtc();
  final String id;
  final DateTime occurredAt;
  final AuditActor actor;
  final String action;
  final String recordType;
  final String? recordId;
  final String outcome;
  final int statusCode;

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

const auditRetention = Duration(days: 365);
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

/// Extract only typed, numeric identifiers and allowlisted operation names.
/// Each grouped Feeding has its own affected-record event.
List<AuditEvent> collectionAuditEvents(
  AuditActor actor,
  String method,
  List<String> path,
  int status,
  Map<String, dynamic>? reply, {
  bool replayed = false,
}) {
  if (path.isEmpty) return [];
  const roots = {
    'boxes': 'box',
    'animals': 'animal',
    'feedings': 'feeding',
    'media': 'media',
  };
  var type = roots[path.first];
  if (type == null) return [];
  String? numeric(String? text) => int.tryParse(text ?? '')?.toString();
  var target = path.length > 1 ? numeric(path[1]) : null;
  var operation = switch (method) {
    'POST' => 'create',
    'DELETE' => 'delete',
    'PUT' || 'PATCH' => 'update',
    _ => 'unknown',
  };
  if (path.length > 2) {
    final section = path[2];
    if (const {
      'archive',
      'restore',
      'duplicate',
      'move',
      'feeding-reminder',
    }.contains(section)) {
      operation = section;
    } else if (const {'pictures', 'weights', 'shedding'}.contains(section)) {
      type = section == 'pictures'
          ? 'media'
          : section == 'weights'
          ? 'weight'
          : section;
      target = path.length > 3 ? numeric(path[3]) : null;
      if (path.length > 4 && path[4] == 'primary') operation = 'set_primary';
    }
  }
  final ids = <String>[];
  if (status < 400 && reply != null) {
    if (reply['feedings'] case final List<dynamic> feedings) {
      for (final record in feedings) {
        if (record is Map && record['id'] is int) ids.add('${record['id']}');
      }
    } else {
      for (final key in [
        'box',
        'animal',
        'feeding',
        'weight',
        'shedding',
        'picture',
      ]) {
        final record = reply[key];
        if (record is Map) {
          final value = key == 'picture' ? record['mediaId'] : record['id'];
          if (value is int) {
            ids.add('$value');
            break;
          }
        }
      }
      if (ids.isEmpty && reply['id'] is int) ids.add('${reply['id']}');
    }
  }
  return [
    for (final id in ids.isEmpty ? <String?>[target] : ids)
      AuditEvent(
        actor: actor,
        action: '$type.$operation',
        recordType: type,
        recordId: id,
        outcome: replayed
            ? 'replayed'
            : status < 400
            ? 'success'
            : 'rejected',
        statusCode: status,
      ),
  ];
}
