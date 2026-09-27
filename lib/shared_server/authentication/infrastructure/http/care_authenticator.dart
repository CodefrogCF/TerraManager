import 'dart:io';

/// Authorizes collection requests before any database or media access.
abstract class CareAuthenticator {
  Future<bool> isAuthenticated(HttpRequest request);
}
