import 'dart:io';

import 'account_store.dart';
import 'api_input.dart';
import 'care_authenticator.dart';

class SessionAuthenticator implements CareAuthenticator {
  static const cookieName = '__Host-TerraManagerSession';

  final AccountStore accounts;
  final String publicOrigin;

  SessionAuthenticator(this.accounts, Uri publicUrl)
    : publicOrigin = publicUrl.origin {
    if (!publicUrl.hasScheme ||
        publicUrl.host.isEmpty ||
        (publicUrl.scheme != 'https' &&
            !(publicUrl.scheme == 'http' &&
                {'localhost', '127.0.0.1', '::1'}.contains(publicUrl.host)))) {
      throw ArgumentError.value(
        publicUrl,
        'publicUrl',
        'An HTTPS origin is required outside localhost.',
      );
    }
  }

  CareSession? session(HttpRequest request) {
    final cookies = request.cookies.where(
      (cookie) => cookie.name == cookieName,
    );
    if (cookies.length != 1) return null;
    return accounts.findSession(cookies.single.value);
  }

  void checkOrigin(HttpRequest request) {
    final origin = request.headers.value('Origin');
    if (origin != null && origin != publicOrigin) {
      throw const ApiProblem(
        403,
        'forbidden',
        'Request origin is not allowed.',
      );
    }
    final fetchSite = request.headers.value('Sec-Fetch-Site');
    if (fetchSite != null &&
        fetchSite != 'same-origin' &&
        fetchSite != 'none') {
      throw const ApiProblem(403, 'forbidden', 'Cross-origin request denied.');
    }
  }

  void checkMutation(HttpRequest request, CareSession session) {
    checkOrigin(request);
    final supplied = request.headers.value('X-CSRF-Token');
    if (supplied == null || !_constantTimeEqual(supplied, session.csrfToken)) {
      throw const ApiProblem(
        403,
        'csrf_failed',
        'CSRF token is missing or invalid.',
      );
    }
  }

  @override
  Future<bool> isAuthenticated(HttpRequest request) async {
    final current = session(request);
    if (current == null) return false;
    if (!{'GET', 'HEAD', 'OPTIONS'}.contains(request.method)) {
      checkMutation(request, current);
    }
    return true;
  }

  static String cookieHeader(String token) =>
      '$cookieName=$token; Path=/; Max-Age=${AccountStore.sessionLifetime.inSeconds}; Secure; HttpOnly; SameSite=Strict';

  static String clearCookieHeader() =>
      '$cookieName=; Path=/; Max-Age=0; Secure; HttpOnly; SameSite=Strict';

  static bool _constantTimeEqual(String left, String right) {
    var difference = left.length ^ right.length;
    for (var i = 0; i < right.length; i++) {
      difference |=
          right.codeUnitAt(i) ^ (i < left.length ? left.codeUnitAt(i) : 0);
    }
    return difference == 0;
  }
}
