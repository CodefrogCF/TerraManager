/// A deliberately small read model: no collection payloads or credentials.
class SharedAuditEvent {
  const SharedAuditEvent({
    required this.id,
    required this.source,
    required this.occurredAt,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.recordType,
    required this.recordId,
    required this.outcome,
    required this.statusCode,
  });
  final String id;
  final String source;
  final DateTime occurredAt;
  final String actorName;
  final String actorRole;
  final String action;
  final String recordType;
  final String? recordId;
  final String outcome;
  final int statusCode;

  factory SharedAuditEvent.fromJson(Map<String, dynamic> json) =>
      SharedAuditEvent(
        id: json['id'] as String,
        source: json['source'] as String,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        actorName: json['actorName'] as String,
        actorRole: json['actorRole'] as String,
        action: json['action'] as String,
        recordType: json['recordType'] as String,
        recordId: json['recordId'] as String?,
        outcome: json['outcome'] as String,
        statusCode: json['statusCode'] as int,
      );
}

class SharedAuditPage {
  const SharedAuditPage(this.events, this.nextCursor);
  final List<SharedAuditEvent> events;
  final String? nextCursor;

  factory SharedAuditPage.fromJson(Map<String, dynamic> json) =>
      SharedAuditPage(
        (json['events'] as List<dynamic>)
            .map(
              (value) =>
                  SharedAuditEvent.fromJson(value as Map<String, dynamic>),
            )
            .toList(),
        json['nextCursor'] as String?,
      );
}
