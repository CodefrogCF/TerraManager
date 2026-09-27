import 'dart:async';

import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

class AuthenticationOperations {
  AuthenticationOperations(this.accounts);
  final AccountStore accounts;
  final Map<String, List<DateTime>> _failedLogins = {};
  Future<CareSession> login(
    String username,
    String password,
    String? remoteAddress,
  ) async {
    final key = '$remoteAddress:$username';
    final now = DateTime.now().toUtc();
    _failedLogins.removeWhere((_, attempts) {
      attempts.removeWhere(
        (time) => now.difference(time) > const Duration(minutes: 5),
      );
      return attempts.isEmpty;
    });
    if ((_failedLogins[key]?.length ?? 0) >= 5) {
      throw const ApiProblem(429, 'rate_limited', 'Try again later.');
    }
    final account = await accounts.authenticate(username, password);
    if (account == null) {
      if (_failedLogins.length > 1000) _failedLogins.clear();
      _failedLogins.putIfAbsent(key, () => []).add(now);
      throw const ApiProblem(
        401,
        'invalid_credentials',
        'Invalid credentials.',
      );
    }
    _failedLogins.remove(key);
    return accounts.createSession(account);
  }
}
