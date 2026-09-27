import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_payload.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedSettingsApi on SharedApiTransport {
  Future<Map<String, dynamic>> updatePreferences(
    Map<String, Object> patch,
  ) async => readApiObject(
    await requestJson('PATCH', '/api/v1/auth/preferences', body: patch),
    'preferences',
  );
}
