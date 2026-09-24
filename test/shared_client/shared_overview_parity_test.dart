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

  testWidgets('shared Box overview sorts naturally and renames through API', (
    tester,
  ) async {
    final boxes = <Map<String, dynamic>>[
      {
        'id': 1,
        'name': 'Terrarium 10',
        'status': 'active',
        'revision': 'rev-1',
      },
      {'id': 2, 'name': 'Terrarium 2', 'status': 'active', 'revision': 'rev-1'},
    ];
    var writes = 0;
    var archives = 0;
    final backend = MockClient((request) async {
      switch (request.url.path) {
        case '/api/v1/auth/session':
          return http.Response(jsonEncode(_session), 200);
        case '/api/v1/boxes':
          return http.Response(jsonEncode({'boxes': boxes}), 200);
        case '/api/v1/animals':
          return http.Response(jsonEncode({'animals': []}), 200);
        case '/api/v1/boxes/1':
          if (request.method == 'PATCH') {
            writes++;
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            expect(payload, {'name': 'Renamed', 'expectedRevision': 'rev-1'});
            boxes[0] = {
              ...boxes[0],
              'name': payload['name'],
              'revision': 'rev-2',
            };
            return http.Response(jsonEncode({'box': boxes[0]}), 200);
          }
        case '/api/v1/boxes/1/archive':
          archives++;
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['reason'], 'sold');
          boxes[0] = {...boxes[0], 'status': 'archived'};
          return http.Response(jsonEncode({'box': boxes[0]}), 200);
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      SharedCareApp(
        api: SharedApiClient(Uri.parse('https://192.168.1.117'), backend),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('box-sort-button')), findsOneWidget);
    expect(find.byKey(const Key('add-box-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('box-sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('box-sort-option-name')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Terrarium 2')).dy,
      lessThan(tester.getTopLeft(find.text('Terrarium 10')).dy),
    );

    await tester.longPress(find.byKey(const Key('box-list-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename Box'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Renamed');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Renamed'), findsOneWidget);

    await tester.longPress(find.byKey(const Key('box-list-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive Box'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(archives, 1);
    expect(find.text('Renamed'), findsNothing);
    await tester.tap(find.byKey(const Key('box-archive-button')));
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
  });
}

const _session = {
  'user': {'username': 'hagen', 'role': 'administrator'},
  'csrfToken': 'csrf-secret',
  'expiresAt': '2026-09-24T08:00:00Z',
};
