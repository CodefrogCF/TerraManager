import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_care_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'a disconnected save stays open and reconnection loads server changes',
    (tester) async {
      var signedIn = false;
      var offline = false;
      var writes = 0;
      final boxes = <Map<String, dynamic>>[
        {'id': 1, 'name': 'Before', 'status': 'active'},
      ];
      final backend = MockClient((request) async {
        if (offline && request.method != 'POST') {
          throw http.ClientException('offline');
        }
        switch (request.url.path) {
          case '/api/v1/auth/session':
            if (signedIn) return http.Response(jsonEncode(_session), 200);
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'unauthorized',
                  'message': 'Authentication required.',
                },
              }),
              401,
            );
          case '/api/v1/auth/login':
            signedIn = true;
            return http.Response(jsonEncode(_session), 200);
          case '/api/v1/boxes':
            if (request.method == 'POST') {
              writes++;
              final input = jsonDecode(request.body) as Map<String, dynamic>;
              final box = <String, dynamic>{
                'id': boxes.length + 1,
                'name': input['name'],
                'status': 'active',
              };
              boxes.add(box);
              // The server committed the write, but the browser lost its reply.
              if (offline) throw http.ClientException('response lost');
              return http.Response(jsonEncode({'box': box}), 201);
            }
            return http.Response(jsonEncode({'boxes': boxes}), 200);
          case '/api/v1/animals':
            return http.Response(jsonEncode({'animals': []}), 200);
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        SharedCareApp(
          api: SharedApiClient(Uri.parse('https://192.168.1.117'), backend),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('shared-username')), 'hagen');
      await tester.enterText(
        find.byKey(const Key('shared-password')),
        'secret password',
      );
      await tester.tap(find.byKey(const Key('shared-login')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Before'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-box-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Unconfirmed Box',
      );
      offline = true;
      await tester.tap(find.byKey(const Key('shared-save-box')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shared-save-box')), findsOneWidget);
      expect(find.textContaining('result is uncertain'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('shared-save-box')))
            .onPressed,
        isNull,
      );
      expect(writes, 1);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shared-error')), findsOneWidget);
      expect(find.textContaining('Unconfirmed Box'), findsNothing);
      offline = false;
      boxes.add({'id': 2, 'name': 'From another browser', 'status': 'active'});
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shared-error')), findsNothing);
      expect(find.textContaining('Unconfirmed Box'), findsOneWidget);
      expect(find.textContaining('From another browser'), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(
              find.byKey(const Key('add-box-button')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
}

const _session = {
  'user': {'username': 'hagen', 'role': 'administrator'},
  'csrfToken': 'csrf-secret',
  'expiresAt': '2026-09-24T08:00:00Z',
};
