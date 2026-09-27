import 'package:terramanager/shared_server/accounts/domain/care_account.dart';

class CareSession {
  final String token;
  final String csrfToken;
  final DateTime expiresAt;
  final CareAccount account;

  const CareSession(this.token, this.csrfToken, this.expiresAt, this.account);
}
