import 'package:terramanager/shared_client/authentication/domain/shared_session.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedAuthenticationApi on SharedApiTransport {
  Future<SharedSession?> restoreSession() async {
    final owner = sessionState;
    try {
      final json = await requestJson('GET', '/api/v1/auth/session');
      if (!identical(owner, sessionState)) return sessionState;
      final restored = SharedSession.fromJson(json);
      final current = sessionState;
      if (current == null ||
          current.csrfToken != restored.csrfToken ||
          current.username != restored.username ||
          current.role != restored.role) {
        sessionState = restored;
        notifyListeners();
      }
      return sessionState;
    } on SharedApiException catch (error) {
      if (error.status == 401) {
        if (identical(owner, sessionState)) sessionState = null;
        return sessionState;
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
    final owner = sessionState;
    await requestJson('POST', '/api/v1/auth/logout');
    if (!identical(owner, sessionState)) return;
    sessionState = null;
    notifyListeners();
  }
}
