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

  testWidgets('stale Box edit reloads values before another save', (
    tester,
  ) async {
    var box = <String, dynamic>{
      'id': 1,
      'name': 'Opened value',
      'status': 'active',
      'revision': 'revision-1',
    };
    var writes = 0;
    final backend = MockClient((request) async {
      switch (request.url.path) {
        case '/api/v1/auth/session':
          return http.Response(
            jsonEncode({
              'user': {'username': 'hagen', 'role': 'administrator'},
              'csrfToken': 'test-csrf',
              'expiresAt': '2026-09-25T12:00:00Z',
            }),
            200,
          );
        case '/api/v1/boxes':
          return http.Response(
            jsonEncode({
              'boxes': [box],
            }),
            200,
          );
        case '/api/v1/animals':
          return http.Response(jsonEncode({'animals': []}), 200);
        case '/api/v1/reminders':
          return http.Response(jsonEncode({'reminders': []}), 200);
        case '/api/v1/boxes/1':
          if (request.method == 'PATCH') {
            final input = jsonDecode(request.body) as Map<String, dynamic>;
            if (input['expectedRevision'] != box['revision']) {
              return http.Response(
                jsonEncode({
                  'error': {
                    'code': 'stale_record',
                    'message': 'Reload and review.',
                  },
                }),
                409,
              );
            }
            writes++;
            box = {...box, 'name': input['name'], 'revision': 'revision-3'};
          }
          return http.Response(jsonEncode({'box': box}), 200);
        case '/api/v1/boxes/1/pictures':
          return http.Response(jsonEncode({'pictures': []}), 200);
      }
      return http.Response('{}', 404);
    });
    await tester.pumpWidget(
      SharedCareApp(
        api: SharedApiClient(Uri.parse('https://192.168.1.117'), backend),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('box-list-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Box'));
    await tester.pumpAndSettle();

    box = {...box, 'name': 'Changed elsewhere', 'revision': 'revision-2'};
    await tester.enterText(find.byType(TextFormField).first, 'My change');
    await tester.tap(find.byKey(const Key('shared-save-box')));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('Reload and review'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-save-box')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('shared-save-box')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Reload and review'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Changed elsewhere'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Reviewed change');
    await tester.tap(find.byKey(const Key('shared-save-box')));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(box['name'], 'Reviewed change');
  });
}
