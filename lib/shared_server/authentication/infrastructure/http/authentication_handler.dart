import 'dart:async';
import 'dart:io';

import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/authentication/application/account_input.dart';
import 'package:terramanager/shared_server/authentication/application/authentication_operations.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/http/session_authenticator.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_response.dart';

class AuthenticationHandler {
  AuthenticationHandler(this.accounts)
    : operations = AuthenticationOperations(accounts);
  final AccountStore accounts;
  final AuthenticationOperations operations;
  Future<void> login(HttpRequest request) async {
    final input = await readAccountBody(request);
    input.allow(const {'username', 'password'});
    final username = input.string('username', maxLength: 64).toLowerCase();
    final password = readAccountPassword(input);
    final session = await operations.login(
      username,
      password,
      request.connectionInfo?.remoteAddress.address,
    );
    final account = session.account;
    request.response.headers.add(
      HttpHeaders.setCookieHeader,
      SessionAuthenticator.cookieHeader(session.token),
    );
    await sendApiResponse(request.response, 200, {
      'user': account.toJson(),
      'csrfToken': session.csrfToken,
      'expiresAt': session.expiresAt.toIso8601String(),
      'preferences': accounts.preferences(account.id),
    });
  }

  Future<void> session(HttpRequest request, CareSession current) async {
    await sendApiResponse(request.response, 200, {
      'user': current.account.toJson(),
      'csrfToken': current.csrfToken,
      'expiresAt': current.expiresAt.toIso8601String(),
      'preferences': accounts.preferences(current.account.id),
    });
    return;
  }

  Future<void> logout(HttpRequest request, CareSession current) async {
    accounts.revokeSession(current.token);
    request.response.headers.add(
      HttpHeaders.setCookieHeader,
      SessionAuthenticator.clearCookieHeader(),
    );
    await sendApiResponse(request.response, 200, {'loggedOut': true});
    return;
  }
}
