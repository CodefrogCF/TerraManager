import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/audit/shared_audit_section.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';

Map<String, dynamic> _event(String id) => {
  'id': id, 'source': 'collection', 'occurredAt': '2026-09-27T10:30:00.000Z',
  'actorId': 'stable-alice', 'actorName': 'alice', 'actorRole': 'caregiver',
  'action': 'animal.update', 'recordType': 'animal', 'recordId': '42',
  'outcome': 'success', 'statusCode': 200,
  // Even an unexpected payload field must not be rendered by the read model.
  'notes': 'PRIVATE NOTE', 'password': 'PASSWORD SECRET',
};

Future<SharedApiClient> _api(
  Future<http.Response> Function(http.Request) handler, {
  String role = 'administrator',
}) async {
  final api = SharedApiClient(
    Uri.parse('https://terramanager.home.arpa'),
    MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'user': {'username': 'admin', 'role': role},
            'csrfToken': 'csrf-secret',
          }),
          200,
        );
      }
      return handler(request);
    }),
  );
  await api.login('admin', 'password');
  return api;
}

Widget _app(SharedApiClient api, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: SharedAuditViewerPage(api: api),
    );

void main() {
  testWidgets('page navigation and combined filters reset to the first page', (
    tester,
  ) async {
    final queries = <Map<String, String>>[];
    final api = await _api((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/admin/audit');
      queries.add(request.url.queryParameters);
      return http.Response(
        jsonEncode({
          'events': [
            _event(
              request.url.queryParameters['cursor'] == null
                  ? 'first'
                  : 'second',
            ),
          ],
          'nextCursor': request.url.queryParameters['cursor'] == null
              ? 'next-page'
              : null,
        }),
        200,
      );
    });
    addTearDown(api.close);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(find.text('alice · Caregiver'), findsOneWidget);
    expect(find.text('Animal · Updated'), findsOneWidget);
    expect(find.text('Animal · ID 42'), findsOneWidget);
    expect(find.textContaining('PRIVATE NOTE'), findsNothing);
    expect(find.textContaining('PASSWORD SECRET'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('audit-next')));
    await tester.tap(find.byKey(const Key('audit-next')));
    await tester.pumpAndSettle();
    expect(queries.last['cursor'], 'next-page');
    expect(find.text('Page 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('audit-previous')));
    await tester.pumpAndSettle();
    expect(queries.last.containsKey('cursor'), false);
    await tester.ensureVisible(find.byKey(const Key('audit-actor')));
    await tester.enterText(find.byKey(const Key('audit-actor')), ' Alice ');
    await tester.tap(find.byKey(const Key('audit-action-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Updated').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audit-from')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audit-through')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audit-apply')));
    await tester.pumpAndSettle();
    expect(queries.last['actor'], 'Alice');
    expect(queries.last['action'], 'update');
    final localDate = DateTime.now();
    expect(
      DateTime.parse(queries.last['from']!),
      DateTime(localDate.year, localDate.month, localDate.day).toUtc(),
    );
    expect(
      DateTime.parse(queries.last['until']!),
      DateTime(localDate.year, localDate.month, localDate.day + 1).toUtc(),
    );
    expect(queries.last.containsKey('cursor'), false);
    await tester.tap(find.byKey(const Key('audit-reset')));
    await tester.pumpAndSettle();
    expect(queries.last, {'limit': '20'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty history differs from no matching events', (tester) async {
    final api = await _api(
      (_) async => http.Response('{"events":[],"nextCursor":null}', 200),
    );
    addTearDown(api.close);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(find.text('No events yet.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('audit-actor')), 'missing');
    await tester.tap(find.byKey(const Key('audit-apply')));
    await tester.pumpAndSettle();
    expect(find.text('No events match these filters.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('audit-next')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('caregivers cannot open the viewer or issue an audit request', (
    tester,
  ) async {
    var requests = 0;
    final api = await _api((_) async {
      requests++;
      return http.Response('{}', 403);
    }, role: 'caregiver');
    addTearDown(api.close);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(find.text('Administrator access required.'), findsOneWidget);
    expect(find.byKey(const Key('audit-actor')), findsNothing);
    await expectLater(api.auditEvents(), throwsA(isA<SharedApiException>()));
    expect(requests, 0);
  });

  testWidgets(
    'failed requests can be retried and expired access hides loaded events',
    (tester) async {
      var count = 0;
      final api = await _api((_) async {
        count++;
        if (count == 1) {
          return http.Response('{"error":{"code":"restore_in_progress"}}', 503);
        }
        if (count == 3) {
          return http.Response('{"error":{"code":"unauthorized"}}', 401);
        }
        return http.Response(
          jsonEncode({
            'events': [_event('one')],
            'nextCursor': null,
          }),
          200,
        );
      });
      addTearDown(api.close);
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('audit-retry')));
      await tester.pumpAndSettle();
      expect(find.text('alice · Caregiver'), findsOneWidget);
      await tester.tap(find.byKey(const Key('audit-refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Administrator access required.'), findsOneWidget);
      expect(find.text('alice · Caregiver'), findsNothing);
    },
  );

  for (final size in [const Size(320, 844), const Size(1280, 900)]) {
    testWidgets('German audit view fits $size with long account identifiers', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = await _api(
        (_) async => http.Response(
          jsonEncode({
            'events': [
              {
                ..._event('long'),
                'actorName': 'a' * 64,
                'recordType': 'account',
                'recordId': '11111111-1111-4111-8111-111111111111',
                'action': 'account.delete',
                'outcome': 'rejected',
                'statusCode': 409,
              },
            ],
            'nextCursor': null,
          }),
          200,
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(_app(api, locale: const Locale('de')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('audit-action-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fütterungserinnerung geändert').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('audit-event-collection-long')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Konto · Gelöscht'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('audit-next')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Seite 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
