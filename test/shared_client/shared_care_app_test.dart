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
    'sign-in loads the shared collection and disconnect blocks edits',
    (tester) async {
      var signedIn = false;
      var offline = false;
      final backend = MockClient((request) async {
        if (offline) throw http.ClientException('offline');
        if (request.url.path == '/api/v1/auth/session') {
          return signedIn
              ? http.Response(jsonEncode(_session), 200)
              : http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'unauthorized',
                      'message': 'Authentication required.',
                    },
                  }),
                  401,
                );
        }
        if (request.url.path == '/api/v1/auth/login') {
          signedIn = true;
          return http.Response(jsonEncode(_session), 200);
        }
        if (request.url.path == '/api/v1/boxes') {
          return http.Response(
            jsonEncode({
              'boxes': [
                {'id': 1, 'name': 'Shared Box', 'status': 'active'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/animals') {
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
      expect(find.byKey(const Key('shared-login')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('shared-username')), 'hagen');
      await tester.enterText(
        find.byKey(const Key('shared-password')),
        'secret password',
      );
      await tester.tap(find.byKey(const Key('shared-login')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Shared Box'), findsOneWidget);

      offline = true;
      await tester.tap(find.byKey(const Key('shared-refresh')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shared-error')), findsOneWidget);
      final addButton = tester.widget<FloatingActionButton>(
        find.byKey(const Key('add-box-button')),
      );
      expect(addButton.onPressed, isNull);
    },
  );

  testWidgets('visible overview refreshes and pauses in the background', (
    tester,
  ) async {
    var boxName = 'First name';
    var reads = 0;
    final backend = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/session') {
        return http.Response(jsonEncode(_session), 200);
      }
      if (request.url.path == '/api/v1/boxes') {
        reads++;
        return http.Response(
          jsonEncode({
            'boxes': [
              {'id': 1, 'name': boxName, 'status': 'active'},
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/api/v1/animals') {
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
    expect(find.textContaining('First name'), findsOneWidget);

    boxName = 'Second name';
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.textContaining('Second name'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final pausedReads = reads;
    boxName = 'Third name';
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(reads, pausedReads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Third name'), findsOneWidget);
  });
}

const _session = {
  'user': {'username': 'hagen', 'role': 'administrator'},
  'csrfToken': 'csrf-secret',
  'expiresAt': '2026-09-24T08:00:00Z',
};
