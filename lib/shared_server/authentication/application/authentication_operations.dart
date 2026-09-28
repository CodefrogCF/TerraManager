import 'dart:async';

import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/authentication/application/login_attempt_limiter.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

class AuthenticationOperations {
  AuthenticationOperations(
    AccountStore accounts, {
    Future<CareAccount?> Function(String, String)? authenticate,
  }) : accounts = accounts,
       _authenticate = authenticate ?? accounts.authenticate;

  final AccountStore accounts;
  final Future<CareAccount?> Function(String, String) _authenticate;
  final LoginAttemptLimiter _limiter = LoginAttemptLimiter();

  Future<CareSession> login(String username, String password) async {
    final normalizedUsername = username.trim().toLowerCase();
    final attempt = _limiter.reserve(normalizedUsername);
    if (attempt == null) {
      throw const ApiProblem(
        429,
        'rate_limited',
        'Too many login attempts. Try again later.',
      );
    }

    var resultRecorded = false;
    try {
      final account = await _authenticate(normalizedUsername, password);
      if (account == null) {
        attempt.failed();
        resultRecorded = true;
        throw const ApiProblem(
          401,
          'invalid_credentials',
          'Invalid credentials.',
        );
      }
      final session = accounts.createSession(account);
      attempt.succeeded();
      resultRecorded = true;
      return session;
    } finally {
      if (!resultRecorded) attempt.abort();
    }
  }
}
