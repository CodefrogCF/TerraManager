import 'dart:convert';

import 'audit_event.dart';

/// Read only the metadata allowlist, never account or collection payloads.
const auditReadColumns =
    'id, occurred_at, actor_id, actor_name, actor_role, action, record_type, '
    'record_id, outcome, status_code';

/// Stored UTC timestamps have either millisecond or microsecond precision.
/// Padding makes SQL ordering and seek pagination agree at both precisions.
const auditTimeKeySql =
    "substr(replace(occurred_at, 'Z', '') || '000000', 1, 26)";
const auditReadIndexSql =
    'CREATE INDEX IF NOT EXISTS shared_audit_seek '
    'ON shared_audit_events($auditTimeKeySql DESC, id DESC)';

class AuditQuery {
  AuditQuery._(this.limit, this.where, this.parameters, this.sourceParameter);
  final int limit;
  final String where;
  final List<Object> parameters;
  final int? sourceParameter;

  factory AuditQuery.parse(Uri uri) {
    const keys = {'limit', 'cursor', 'from', 'until', 'actor', 'action'};
    final query = uri.queryParameters;
    for (final entry in uri.queryParametersAll.entries) {
      if (!keys.contains(entry.key) || entry.value.length != 1) {
        throw const FormatException('Unknown or repeated audit filter.');
      }
    }
    final limit = int.tryParse(query['limit'] ?? '20');
    if (limit == null || limit < 1 || limit > 100) {
      throw const FormatException('Audit page size must be between 1 and 100.');
    }
    DateTime? date(String key) {
      final text = query[key];
      if (text == null) return null;
      final value = DateTime.tryParse(text);
      if (value == null || !value.isUtc || value.toIso8601String() != text) {
        throw const FormatException(
          'Audit dates must be canonical UTC timestamps.',
        );
      }
      return value;
    }

    final from = date('from');
    final until = date('until');
    if (from != null && until != null && !from.isBefore(until)) {
      throw const FormatException(
        'Audit date range must start before it ends.',
      );
    }
    final clauses = <String>['$auditTimeKeySql >= ?'];
    final parameters = <Object>[
      _timeKey(DateTime.now().toUtc().subtract(auditRetention)),
    ];
    if (from != null) {
      clauses.add('$auditTimeKeySql >= ?');
      parameters.add(_timeKey(from));
    }
    if (until != null) {
      clauses.add('$auditTimeKeySql < ?');
      parameters.add(_timeKey(until));
    }
    final actor = query['actor'];
    if (actor != null) {
      if (actor.trim().isEmpty || actor.length > 64) {
        throw const FormatException(
          'Audit actor must contain 1 to 64 characters.',
        );
      }
      clauses.add('instr(lower(actor_name), lower(?)) > 0');
      parameters.add(actor.trim());
    }
    final action = query['action'];
    if (action != null) {
      if (!const {
        'create',
        'update',
        'delete',
        'archive',
        'restore',
        'duplicate',
        'move',
        'feeding-reminder',
        'set_primary',
      }.contains(action)) {
        throw const FormatException('Unknown audit action.');
      }
      clauses.add("substr(action, instr(action, '.') + 1) = ?");
      parameters.add(action);
    }
    final cursor = query['cursor'];
    int? sourceParameter;
    if (cursor != null) {
      if (cursor.length > 512) {
        throw const FormatException('Invalid audit cursor.');
      }
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(cursor))),
      );
      if (decoded is! List ||
          decoded.length != 3 ||
          decoded[0] is! String ||
          decoded[1] is! String ||
          decoded[2] is! String ||
          !const {'account', 'collection'}.contains(decoded[1]) ||
          !RegExp(r'^[0-9a-f-]{36}$').hasMatch(decoded[2] as String)) {
        throw const FormatException('Invalid audit cursor.');
      }
      final time = DateTime.tryParse(decoded[0] as String);
      if (time == null || !time.isUtc || time.toIso8601String() != decoded[0]) {
        throw const FormatException('Invalid audit cursor.');
      }
      clauses.add('($auditTimeKeySql, ?, id) < (?, ?, ?)');
      // Each store supplies its own source before these cursor arguments.
      sourceParameter = parameters.length;
      parameters.addAll([
        '',
        _timeKey(time),
        decoded[1] as String,
        decoded[2] as String,
      ]);
    }
    return AuditQuery._(
      limit,
      clauses.join(' AND '),
      parameters,
      sourceParameter,
    );
  }

  List<Object> values(String source) => [
    for (var i = 0; i < parameters.length; i++)
      i == sourceParameter ? source : parameters[i],
    limit + 1,
  ];
  String get sql =>
      'SELECT $auditReadColumns FROM shared_audit_events '
      'WHERE $where ORDER BY $auditTimeKeySql DESC, id DESC LIMIT ?';

  static String _timeKey(DateTime value) =>
      value.toUtc().toIso8601String().replaceAll('Z', '').padRight(26, '0');
}

Map<String, Object?> auditMetadata(Map<String, Object?> row, String source) => {
  'id': row['id'],
  'source': source,
  'occurredAt': row['occurred_at'],
  'actorId': row['actor_id'],
  'actorName': row['actor_name'],
  'actorRole': row['actor_role'],
  'action': row['action'],
  'recordType': row['record_type'],
  'recordId': row['record_id'],
  'outcome': row['outcome'],
  'statusCode': row['status_code'],
};

Map<String, Object?> auditPage(List<Map<String, Object?>> events, int limit) {
  events.sort((a, b) {
    final time = DateTime.parse(b['occurredAt'] as String)
        .compareTo(DateTime.parse(a['occurredAt'] as String));
    if (time != 0) return time;
    final source = (b['source'] as String).compareTo(a['source'] as String);
    return source != 0
        ? source
        : (b['id'] as String).compareTo(a['id'] as String);
  });
  final hasMore = events.length > limit;
  final page = events.take(limit).toList();
  final last = page.isEmpty ? null : page.last;
  return {
    'events': page,
    'nextCursor': hasMore && last != null
        ? base64Url.encode(
            utf8.encode(
              jsonEncode([last['occurredAt'], last['source'], last['id']]),
            ),
          )
        : null,
  };
}
