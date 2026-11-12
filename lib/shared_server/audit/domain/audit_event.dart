import 'package:uuid/uuid.dart';

/// Server-owned metadata. Never pass request bodies, headers or notes here.
class AuditActor {
  const AuditActor(this.id, this.name, this.role);
  final String id;
  final String name;
  final String role;
}

/// The affected Box, Animal or account as known when the event was recorded.
class AuditSubject {
  const AuditSubject(this.type, this.id, this.label);
  final String type;
  final String id;
  final String? label;
}

class AuditEvent {
  AuditEvent({
    required this.actor,
    required this.action,
    required this.recordType,
    required this.recordId,
    required this.outcome,
    required this.statusCode,
    this.subject,
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
  final AuditSubject? subject;
}

const auditRetention = Duration(days: 365);
