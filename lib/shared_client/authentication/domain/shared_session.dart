import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';

class SharedSession {
  const SharedSession({
    required this.username,
    required this.role,
    required this.csrfToken,
    this.preferences = const {},
  });

  final String username;
  final String role;
  final String csrfToken;
  final Map<String, dynamic> preferences;

  factory SharedSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final csrf = json['csrfToken'];
    if (user is! Map ||
        user['username'] is! String ||
        user['role'] is! String ||
        csrf is! String) {
      throw const SharedApiException(
        200,
        'invalid_response',
        'The server returned an invalid session.',
      );
    }
    return SharedSession(
      preferences: json['preferences'] is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(
              json['preferences'] as Map<String, dynamic>,
            )
          : const {},
      username: user['username'] as String,
      role: user['role'] as String,
      csrfToken: csrf,
    );
  }
}
