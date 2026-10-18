import 'dart:convert';

import 'package:http/http.dart' as http;

/// Conditional-query fixture: callers choose the revision and affected owners.
http.Response fakeChangeResponse(
  http.Request request,
  String cursor, {
  Map<String, Object?> resources = const {},
}) {
  if (request.url.queryParameters['since'] == cursor) {
    return http.Response('', 304, headers: {'x-shared-care-cursor': cursor});
  }
  return http.Response(
    jsonEncode({
      'cursor': cursor,
      'reset': request.url.queryParameters['since'] == null,
      'epoch': 'test',
      'revision': 0,
      'preferencesRevision': 0,
      'preferencesChanged': false,
      'changes': [
        {'resources': resources},
      ],
    }),
    200,
  );
}
