import 'package:terramanager/shared_server/audit/domain/audit_event.dart';

enum CareRole { administrator, caregiver }

class CareAccount {
  final int id;
  final String username;
  final CareRole role;
  final bool active;
  final String auditId;

  AuditActor get auditActor => AuditActor(auditId, username, role.name);

  const CareAccount(
    this.id,
    this.username,
    this.role,
    this.active, [
    this.auditId = '',
  ]);

  Map<String, Object> toJson() => {
    'id': id,
    'username': username,
    'role': role.name,
    'active': active,
    'auditId': auditId,
  };
}
