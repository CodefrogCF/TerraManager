import 'dart:async';
import 'dart:io';

import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_response.dart';

class PreferencesHandler {
  const PreferencesHandler(this.accounts);
  final AccountStore accounts;
  Future<bool> handle(HttpRequest request, CareSession current) async {
    if (request.method == 'GET') {
      await sendApiResponse(request.response, 200, {
        'preferences': accounts.preferences(current.account.id),
      });
      return true;
    }
    if (request.method == 'PATCH') {
      final input = await readAccountBody(request);
      final preferences = accounts.updatePreferences(
        current.account.id,
        input.values,
      );
      await sendApiResponse(request.response, 200, {
        'preferences': preferences,
      });
      return true;
    }

    return false;
  }
}
