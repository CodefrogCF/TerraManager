import 'dart:convert';

import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

/// A 304 deliberately carries no JSON. It preserves the caller's applied cursor.
class SharedChangeQuery {
  const SharedChangeQuery({required this.cursor, this.body});
  final String cursor;
  final Map<String, dynamic>? body;
  bool get notModified => body == null;
}

mixin SharedChangesApi on SharedApiTransport {
  Future<SharedChangeQuery> queryChanges({String? since}) async {
    final query = since == null
        ? ''
        : '?since=${Uri.encodeQueryComponent(since)}';
    final response = await requestBinary(
      'GET',
      '/api/v1/changes$query',
      timeout: const Duration(seconds: 15),
      allowNotModified: true,
      extraHeaders: {
        'Accept': 'application/json',
        if (since != null) 'If-None-Match': '"$since"',
      },
    );
    if (response.statusCode == 304) {
      if (since == null || response.headers['x-shared-care-cursor'] != since) {
        throw const SharedApiException(
          304,
          'invalid_response',
          'Invalid change cursor.',
        );
      }
      return SharedChangeQuery(cursor: since);
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['cursor'] is! String ||
          body['reset'] is! bool ||
          body['changes'] is! List ||
          body['preferencesChanged'] is! bool ||
          body['epoch'] is! String ||
          body['revision'] is! int ||
          body['preferencesRevision'] is! int) {
        throw const FormatException();
      }
      return SharedChangeQuery(cursor: body['cursor'] as String, body: body);
    } catch (_) {
      throw const SharedApiException(
        200,
        'invalid_response',
        'Invalid change response.',
      );
    }
  }
}
