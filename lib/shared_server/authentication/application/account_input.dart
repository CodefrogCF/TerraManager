import 'dart:convert';

import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

CareRole parseAccountRole(String value) {
  if (value == CareRole.administrator.name) return CareRole.administrator;
  if (value == CareRole.caregiver.name) return CareRole.caregiver;
  throw const ApiProblem(400, 'invalid_data', 'Unknown account role.');
}

String readAccountPassword(ApiInput input) {
  final value = input.values['password'];
  if (value is! String || utf8.encode(value).length > 1024) {
    throw const ApiProblem(400, 'invalid_data', 'Invalid password.');
  }
  return value;
}
