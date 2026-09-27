import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_payload.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedAccountsApi on SharedApiTransport {
  Future<List<Map<String, dynamic>>> accounts() async => readApiList(
    await requestJson('GET', '/api/v1/admin/accounts'),
    'accounts',
  );

  Future<Map<String, dynamic>> createAccount(
    String username,
    String password,
    String role,
  ) async => readApiObject(
    await requestJson(
      'POST',
      '/api/v1/admin/accounts',
      body: {'username': username, 'password': password, 'role': role},
    ),
    'account',
  );

  Future<Map<String, dynamic>> updateAccount(
    int id,
    Map<String, dynamic> values,
  ) async {
    final result = await requestJson(
      'PATCH',
      '/api/v1/admin/accounts/$id',
      body: values,
    );
    final account = readApiObject(result, 'account');
    accountSessionChanged(result);
    return account;
  }

  Future<void> removeAccount(int id, String expectedAuditId) async {
    final result = await requestJson(
      'DELETE',
      '/api/v1/admin/accounts/$id',
      body: {
        'confirmation': 'remove-account',
        'expectedAuditId': expectedAuditId,
      },
    );
    accountSessionChanged(result);
  }
}
