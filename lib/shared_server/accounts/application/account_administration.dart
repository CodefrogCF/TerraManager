import 'dart:async';

import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/authentication/application/account_input.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

class AccountAdministration {
  const AccountAdministration(this.accounts);
  final AccountStore accounts;
  ApiReply list() {
    return ApiReply(200, {
      'accounts': accounts
          .listAccounts()
          .map((account) => account.toJson())
          .toList(),
    });
  }

  Future<ApiReply> create(ApiInput input, CareAccount actor) async {
    input.allow(const {'username', 'password', 'role'});
    final account = await accounts.createAccount(
      input.string('username', maxLength: 64),
      readAccountPassword(input),
      parseAccountRole(input.string('role', maxLength: 32)),
      actor: actor,
    );
    return ApiReply(201, {'account': account.toJson()});
  }

  ApiReply remove(int id, ApiInput input, CareAccount actor) {
    input.allow(const {'confirmation', 'expectedAuditId'});
    if (input.string('confirmation', maxLength: 32) != 'remove-account') {
      throw const ApiProblem(
        400,
        'invalid_data',
        'Account removal must be confirmed.',
      );
    }
    accounts.removeAccount(
      id,
      actor: actor,
      expectedAuditId: input.string('expectedAuditId', maxLength: 64),
    );
    return ApiReply(200, {'removed': true, 'sessionRevoked': id == actor.id});
  }

  Future<ApiReply> update(int id, ApiInput input, CareAccount actor) async {
    input.allow(const {
      'username',
      'password',
      'role',
      'active',
      'expectedAuditId',
    });
    if (input.values.keys.every((key) => key == 'expectedAuditId')) {
      throw const ApiProblem(400, 'invalid_data', 'No fields to update.');
    }
    final active = input.values['active'];
    if (input.values.containsKey('active') && active is! bool) {
      throw const ApiProblem(400, 'invalid_data', 'active must be Boolean.');
    }
    final account = await accounts.updateAccount(
      id,
      expectedAuditId: input.values.containsKey('expectedAuditId')
          ? input.string('expectedAuditId', maxLength: 64)
          : null,
      username: input.values.containsKey('username')
          ? input.string('username', maxLength: 64)
          : null,
      password: input.values.containsKey('password')
          ? readAccountPassword(input)
          : null,
      role: input.values.containsKey('role')
          ? parseAccountRole(input.string('role', maxLength: 32))
          : null,
      active: active as bool?,
      actor: actor,
    );
    return ApiReply(200, {
      'account': account.toJson(),
      'sessionRevoked': id == actor.id,
    });
  }
}
