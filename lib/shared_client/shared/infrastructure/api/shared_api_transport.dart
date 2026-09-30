import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:terramanager/shared_client/authentication/domain/shared_session.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';

/// The shared client deliberately holds no collection data on disk.
abstract class SharedApiTransport extends ChangeNotifier {
  SharedApiTransport(this.origin, this._client) {
    if (origin.scheme != 'https' &&
        !(origin.scheme == 'http' &&
            {'localhost', '127.0.0.1'}.contains(origin.host))) {
      throw ArgumentError.value(origin, 'origin', 'HTTPS is required.');
    }
  }

  final Uri origin;
  final http.Client _client;
  SharedSession? _session;
  bool _connected = false;
  Object? lastFailure;

  SharedSession? get session => _session;
  bool get canDeleteCollection => _session?.role == 'administrator';
  bool get connected => _connected;

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    notifyListeners();
  }

  /// Only feature API mixins may manage authenticated session state.
  @protected
  SharedSession? get sessionState => _session;
  @protected
  set sessionState(SharedSession? value) => _session = value;
  @protected
  Uri apiUrl(String path) {
    if (!path.startsWith('/api/v1/') || path.contains('..')) {
      throw ArgumentError.value(path, 'path', 'Invalid API path.');
    }
    return origin.resolve(path);
  }

  @protected
  void accountSessionChanged(Map<String, dynamic> result) {
    if (result['sessionRevoked'] == true) {
      _session = null;
      notifyListeners();
    }
  }

  @protected
  Future<http.Response> requestBinary(
    String method,
    String path, {
    Uint8List? bytes,
    Duration timeout = const Duration(minutes: 2),
    Map<String, String> extraHeaders = const {},
  }) async {
    final headers = <String, String>{...extraHeaders};
    if (bytes != null) {
      headers['Content-Type'] = 'application/vnd.terramanager.backup+zip';
      final token = _session?.csrfToken;
      if (token == null) {
        throw const SharedApiException(401, 'unauthorized', 'Sign in first.');
      }
      headers['X-CSRF-Token'] = token;
    }
    late final http.Response response;
    try {
      final request = http.Request(method, apiUrl(path));
      request.headers.addAll(headers);
      if (bytes != null) request.bodyBytes = bytes;
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } catch (_) {
      _setConnected(false);
      throw const SharedConnectionException();
    }
    _setConnected(true);
    if (response.statusCode == 401) {
      _session = null;
      notifyListeners();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final payload = jsonDecode(response.body);
        final error = payload is Map ? payload['error'] : null;
        throw SharedApiException(
          response.statusCode,
          error is Map && error['code'] is String
              ? error['code'] as String
              : 'request_failed',
          error is Map && error['message'] is String
              ? error['message'] as String
              : 'The request failed.',
        );
      } on SharedApiException {
        rethrow;
      } catch (_) {
        throw SharedApiException(
          response.statusCode,
          'request_failed',
          'The request failed.',
        );
      }
    }
    return response;
  }

  /// Keeps a successful response body as a stream for large downloads.
  @protected
  Future<http.StreamedResponse> requestDownload(
    String path, {
    Duration timeout = const Duration(minutes: 10),
  }) async {
    late final http.StreamedResponse response;
    try {
      response = await _client
          .send(http.Request('GET', apiUrl(path)))
          .timeout(timeout);
    } catch (_) {
      _setConnected(false);
      throw const SharedConnectionException();
    }
    _setConnected(true);
    if (response.statusCode == 401) {
      _session = null;
      notifyListeners();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    // API errors are small JSON documents. Bound what a faulty server can
    // make us retain while preserving the same useful error as requestBinary.
    final errorBytes = <int>[];
    try {
      await for (final chunk in response.stream.timeout(timeout)) {
        if (errorBytes.length + chunk.length > 64 * 1024) break;
        errorBytes.addAll(chunk);
      }
      final payload = jsonDecode(utf8.decode(errorBytes));
      final error = payload is Map ? payload['error'] : null;
      throw SharedApiException(
        response.statusCode,
        error is Map && error['code'] is String
            ? error['code'] as String
            : 'request_failed',
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'The request failed.',
      );
    } on SharedApiException {
      rethrow;
    } catch (_) {
      throw SharedApiException(
        response.statusCode,
        'request_failed',
        'The request failed.',
      );
    }
  }

  @protected
  Stream<List<int>> downloadBody(
    http.StreamedResponse response, {
    Duration timeout = const Duration(minutes: 10),
  }) async* {
    try {
      yield* response.stream.timeout(timeout);
    } catch (_) {
      _setConnected(false);
      throw const SharedConnectionException();
    }
  }

  @protected
  Future<Map<String, dynamic>> requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requiresSession = true,
    Map<String, String> extraHeaders = const {},
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    headers.addAll(extraHeaders);
    if (!{'GET', 'HEAD'}.contains(method)) lastFailure = null;
    if (body != null) headers['Content-Type'] = 'application/json';
    if (requiresSession && !{'GET', 'HEAD'}.contains(method)) {
      final csrfToken = _session?.csrfToken;
      if (csrfToken == null) {
        throw const SharedApiException(401, 'unauthorized', 'Sign in first.');
      }
      headers['X-CSRF-Token'] = csrfToken;
    }

    late final http.Response response;
    try {
      final request = http.Request(method, apiUrl(path));
      request.headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } catch (_) {
      _setConnected(false);
      lastFailure = const SharedConnectionException();
      throw lastFailure!;
    }
    _setConnected(true);

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      json = decoded;
    } catch (_) {
      final failure = SharedApiException(
        response.statusCode,
        'invalid_response',
        'The server returned an invalid response.',
      );
      lastFailure = failure;
      throw failure;
    }

    if (response.statusCode == 401 && requiresSession) {
      _session = null;
      notifyListeners();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final failure = SharedApiException(
        response.statusCode,
        error is Map && error['code'] is String
            ? error['code'] as String
            : 'request_failed',
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'The request failed.',
      );
      lastFailure = failure;
      throw failure;
    }
    return json;
  }

  void close() {
    _client.close();
    dispose();
  }
}
