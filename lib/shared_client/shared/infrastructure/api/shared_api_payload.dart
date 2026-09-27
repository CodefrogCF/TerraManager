import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';

Map<String, dynamic> readApiObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw const SharedApiException(
    200,
    'invalid_response',
    'The server returned an invalid record.',
  );
}

List<Map<String, dynamic>> readApiList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.every((entry) => entry is Map<String, dynamic>)) {
    return value.cast<Map<String, dynamic>>();
  }
  throw const SharedApiException(
    200,
    'invalid_response',
    'The server returned an invalid collection.',
  );
}
