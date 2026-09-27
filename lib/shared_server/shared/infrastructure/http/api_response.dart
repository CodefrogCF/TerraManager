import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> sendApiResponse(
  HttpResponse response,
  int status,
  Object body,
) async {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.write(jsonEncode(body));
  await response.close();
}
