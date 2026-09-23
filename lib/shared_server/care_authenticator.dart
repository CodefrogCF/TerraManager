import 'dart:convert';
import 'dart:io';

/// Replaceable by local accounts and browser sessions without changing care
/// endpoints.
abstract class CareAuthenticator {
  Future<bool> isAuthenticated(HttpRequest request);
}

/// Temporary API credential. Issue #158 replaces this with per-caregiver
/// accounts and secure browser sessions.
class StaticBearerAuthenticator implements CareAuthenticator {
  final String token;

  StaticBearerAuthenticator(this.token) {
    if (token.length < 32) {
      throw ArgumentError.value(token.length, 'token', 'too short');
    }
  }

  @override
  Future<bool> isAuthenticated(HttpRequest request) async {
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      return false;
    }
    final supplied = utf8.encode(authorization.substring(7));
    final expected = utf8.encode(token);
    var difference = supplied.length ^ expected.length;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ (i < supplied.length ? supplied[i] : 0);
    }
    return difference == 0;
  }
}
