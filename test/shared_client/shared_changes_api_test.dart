import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

void main() {
  test(
    '304 is handled before JSON decoding and validates the applied cursor',
    () async {
      final client = SharedApiClient(
        Uri.parse('https://example.test'),
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.queryParameters['since'], 'epoch:1:1:caregiver:0');
          expect(request.headers['If-None-Match'], '"epoch:1:1:caregiver:0"');
          return http.Response(
            '',
            304,
            headers: {'x-shared-care-cursor': 'epoch:1:1:caregiver:0'},
          );
        }),
      );
      addTearDown(client.close);
      final result = await client.queryChanges(since: 'epoch:1:1:caregiver:0');
      expect(result.notModified, true);
      expect(client.connected, true);
    },
  );
  test(
    'initial reset and subsequent invalidations retain their structured body',
    () async {
      final client = SharedApiClient(
        Uri.parse('https://example.test'),
        MockClient((request) async {
          expect(request.headers.containsKey('If-None-Match'), false);
          return http.Response(
            jsonEncode({
              'epoch': 'epoch',
              'revision': 0,
              'preferencesRevision': 0,
              'cursor': 'cursor',
              'reset': true,
              'preferencesChanged': true,
              'changes': [],
            }),
            200,
          );
        }),
      );
      addTearDown(client.close);
      final result = await client.queryChanges();
      expect(result.notModified, false);
      expect(result.body!['reset'], true);
    },
  );
  test(
    '304 with another cursor and malformed 200 fail rather than advance state',
    () async {
      for (final status in [304, 200]) {
        final client = SharedApiClient(
          Uri.parse('https://example.test'),
          MockClient(
            (_) async => http.Response(
              status == 304 ? '' : '{}',
              status,
              headers: {'x-shared-care-cursor': 'other'},
            ),
          ),
        );
        await expectLater(
          client.queryChanges(since: 'applied'),
          throwsA(isA<SharedApiException>()),
        );
        client.close();
      }
    },
  );
  test(
    'change query unauthorized response clears an existing session',
    () async {
      final client = SharedApiClient(
        Uri.parse('https://example.test'),
        MockClient((request) async {
          if (request.url.path.endsWith('login')) {
            return http.Response(
              jsonEncode({
                'user': {'username': 'tester', 'role': 'caregiver'},
                'csrfToken': 'token',
                'expiresAt': '2030-01-01T00:00:00Z',
              }),
              200,
            );
          }
          return http.Response(
            '{"error":{"code":"unauthorized","message":"Sign in."}}',
            401,
          );
        }),
      );
      addTearDown(client.close);
      await client.login('tester', 'password');
      await expectLater(
        client.queryChanges(),
        throwsA(isA<SharedApiException>()),
      );
      expect(client.session, isNull);
    },
  );
}
