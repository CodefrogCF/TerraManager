import 'package:terramanager/shared_client/authentication/domain/shared_session.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedAuthenticationApi on SharedApiTransport {
  Future<SharedSession?> restoreSession() async {
    try {
      final json = await requestJson('GET', '/api/v1/auth/session');
      sessionState = SharedSession.fromJson(json);
      notifyListeners();
      return sessionState;
    } on SharedApiException catch (error) {
      if (error.status == 401) {
        sessionState = null;
        return null;
      }
      rethrow;
    }
  }

  Future<SharedSession> login(String username, String password) async {
    final json = await requestJson(
      'POST',
      '/api/v1/auth/login',
      body: {'username': username, 'password': password},
      requiresSession: false,
    );
    sessionState = SharedSession.fromJson(json);
    notifyListeners();
    return sessionState!;
  }

  Future<void> logout() async {
    await requestJson('POST', '/api/v1/auth/logout');
    sessionState = null;
    notifyListeners();
  }
}
