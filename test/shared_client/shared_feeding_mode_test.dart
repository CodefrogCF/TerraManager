import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_feeding_box_page.dart';

void main() {
  const origin = 'https://192.168.1.117';
  final session = {
    'user': {'username': 'hagen', 'role': 'caregiver'},
    'csrfToken': 'csrf-secret',
  };
  final animals = {
    'animals': [
      {
        'id': 1,
        'boxId': 7,
        'status': 'active',
        'commonName': 'Animal 1',
        'latinName': 'Species one',
      },
      {
        'id': 2,
        'boxId': 7,
        'status': 'active',
        'commonName': 'Animal 2',
        'latinName': 'Species two',
      },
      {
        'id': 3,
        'boxId': 8,
        'status': 'active',
        'commonName': 'Other Box',
        'latinName': 'Other species',
      },
      {
        'id': 4,
        'boxId': 7,
        'status': 'archived',
        'commonName': 'Archived',
        'latinName': 'Archived species',
      },
    ],
  };

  testWidgets('only active Animals in the scanned Box can be fed', (
    tester,
  ) async {
    http.Request? submission;
    final api = SharedApiClient(
      Uri.parse(origin),
      MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(jsonEncode(session), 200);
        }
        if (request.url.path == '/api/v1/boxes/7') {
          return http.Response(
            jsonEncode({
              'box': {'id': 7, 'status': 'active', 'name': 'Main Box'},
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/animals') {
          return http.Response(jsonEncode(animals), 200);
        }
        if (request.url.path == '/api/v1/feedings') {
          submission = request;
          return http.Response(
            jsonEncode({
              'feedings': [
                {'id': 10, 'animalId': 1},
              ],
            }),
            201,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    await api.login('hagen', 'password');
    await tester.pumpWidget(
      MaterialApp(
        home: SharedFeedingBoxPage(
          api: api,
          box: const {'id': 7, 'status': 'active', 'name': 'Main Box'},
          change: (operation) async {
            await operation();
            return true;
          },
          onReload: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shared-feeding-animal-1')), findsOneWidget);
    expect(find.byKey(const Key('shared-feeding-animal-2')), findsOneWidget);
    expect(find.byKey(const Key('shared-feeding-animal-3')), findsNothing);
    expect(find.byKey(const Key('shared-feeding-animal-4')), findsNothing);

    await tester.tap(find.byKey(const Key('shared-feeding-animal-2')));
    await tester.tap(find.byKey(const Key('shared-feeding-save')));
    await tester.pumpAndSettle();

    expect(submission, isNotNull);
    final body = jsonDecode(submission!.body) as Map<String, dynamic>;
    expect(body['boxId'], 7);
    expect(body['animalIds'], [1]);
    expect(submission!.headers['Idempotency-Key'], isNotEmpty);
  });

  testWidgets('retry after an uncertain response keeps its request key', (
    tester,
  ) async {
    final keys = <String>[];
    var attempts = 0;
    late final SharedApiClient api;
    api = SharedApiClient(
      Uri.parse(origin),
      MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(jsonEncode(session), 200);
        }
        if (request.url.path == '/api/v1/boxes/7') {
          return http.Response(
            jsonEncode({
              'box': {'id': 7, 'status': 'active', 'name': 'Main Box'},
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/animals') {
          return http.Response(
            jsonEncode({
              'animals': [animals['animals']![0]],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/boxes') {
          return http.Response(jsonEncode({'boxes': []}), 200);
        }
        if (request.url.path == '/api/v1/feedings') {
          keys.add(request.headers['Idempotency-Key']!);
          attempts++;
          if (attempts == 1) throw http.ClientException('response lost');
          return http.Response(
            jsonEncode({
              'feedings': [
                {'id': 10, 'animalId': 1},
              ],
            }),
            201,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    await api.login('hagen', 'password');
    await tester.pumpWidget(
      MaterialApp(
        home: SharedFeedingBoxPage(
          api: api,
          box: const {'id': 7, 'status': 'active', 'name': 'Main Box'},
          change: (operation) async {
            try {
              await operation();
              return true;
            } catch (_) {
              return false;
            }
          },
          onReload: () async {
            await api.boxes();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shared-feeding-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shared-feeding-error')), findsOneWidget);
    expect(api.connected, isFalse);

    await tester.tap(find.byKey(const Key('shared-feeding-save')));
    await tester.pumpAndSettle();
    expect(keys, hasLength(2));
    expect(keys[1], keys[0]);
  });
}
