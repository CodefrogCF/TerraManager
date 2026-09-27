import 'dart:async';
import 'dart:io';

import 'package:terramanager/shared_server/accounts/application/account_administration.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_response.dart';

class AccountAdministrationHandler {
  AccountAdministrationHandler(this.accounts)
    : operations = AccountAdministration(accounts);
  final AccountStore accounts;
  final AccountAdministration operations;
  Future<bool> handle(HttpRequest request, CareSession current) async {
    final parts = request.uri.pathSegments;
    if (parts.length == 4 && parts[3] == 'accounts') {
      if (request.method == 'GET') {
        final reply = operations.list();
        await sendApiResponse(request.response, reply.status, reply.body!);
        return true;
      }
      if (request.method == 'POST') {
        final reply = await operations.create(
          await readAccountBody(request),
          current.account,
        );
        await sendApiResponse(request.response, reply.status, reply.body!);
        return true;
      }
    }
    if (parts.length == 5 &&
        parts[3] == 'accounts' &&
        {'DELETE', 'PATCH'}.contains(request.method)) {
      final id = int.tryParse(parts[4]);
      if (id == null || id < 1) {
        throw const ApiProblem(400, 'invalid_data', 'Invalid account ID.');
      }
      if (accounts.accountById(id) == null) {
        throw const ApiProblem(404, 'not_found', 'Account not found.');
      }

      final input = await readAccountBody(request);
      final reply = request.method == 'DELETE'
          ? operations.remove(id, input, current.account)
          : await operations.update(id, input, current.account);
      await sendApiResponse(request.response, reply.status, reply.body!);
      return true;
    }
    return false;
  }
}
