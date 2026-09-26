import 'dart:async';
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

  test('Animal navigation marks only due reminders for active Animals', () {
    final now = DateTime.utc(2026, 9, 25, 12);
    final animals = [
      {'id': 1, 'status': 'active'},
      {'id': 2, 'status': 'archived'},
    ];
    expect(
      hasDueSharedFeedings(animals, [
        {'animalId': 1, 'dueAt': '2026-09-26T12:00:00Z'},
        {'animalId': 2, 'dueAt': '2026-09-24T12:00:00Z'},
      ], now: now),
      isFalse,
    );
    expect(
      hasDueSharedFeedings(animals, [
        {'animalId': 1, 'dueAt': '2026-09-25T12:00:00Z'},
      ], now: now),
      isTrue,
    );
  });

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
        if (request.url.path == '/api/v1/reminders') {
          return http.Response(jsonEncode({'reminders': []}), 200);
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
      if (request.url.path == '/api/v1/reminders') {
        return http.Response(jsonEncode({'reminders': []}), 200);
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

  testWidgets('backup download pauses overview polling until it finishes', (
    tester,
  ) async {
    var boxReads = 0;
    final backupResponse = Completer<http.Response>();
    final backend = MockClient((request) async {
      switch (request.url.path) {
        case '/api/v1/auth/session':
          return http.Response(jsonEncode(_session), 200);
        case '/api/v1/boxes':
          boxReads++;
          return http.Response(jsonEncode({'boxes': []}), 200);
        case '/api/v1/animals':
          return http.Response(jsonEncode({'animals': []}), 200);
        case '/api/v1/reminders':
          return http.Response(jsonEncode({'reminders': []}), 200);
        case '/api/v1/admin/accounts':
          return http.Response(jsonEncode({'accounts': []}), 200);
        case '/api/v1/admin/backups':
          return backupResponse.future;
        default:
          return http.Response('{}', 404);
      }
    });

    await tester.pumpWidget(
      SharedCareApp(
        api: SharedApiClient(Uri.parse('https://192.168.1.117'), backend),
      ),
    );
    await tester.pumpAndSettle();
    expect(boxReads, 1);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-create-backup-button')),
      300,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('shared-create-backup-button'))),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shared-create-backup-button')));
    await tester.pump();

    final readsBeforeWait = boxReads;
    await tester.pump(const Duration(seconds: 16));
    expect(boxReads, readsBeforeWait);
    expect(find.byKey(const Key('shared-error')), findsNothing);

    backupResponse.complete(
      http.Response(
        jsonEncode({
          'error': {'code': 'test_error', 'message': 'Test complete.'},
        }),
        500,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(boxReads, greaterThan(readsBeforeWait));
  });
}

const _session = {
  'user': {'username': 'hagen', 'role': 'administrator'},
  'csrfToken': 'csrf-secret',
  'expiresAt': '2026-09-24T08:00:00Z',
};
