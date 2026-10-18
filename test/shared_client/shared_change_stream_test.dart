import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/shared_client/app/shared_care_app.dart';
import 'package:terramanager/shared_client/changes/application/shared_change_stream.dart';
import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';
import 'package:terramanager/shared_client/changes/domain/shared_event_source_port.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

class _Source implements SharedEventSourcePort {
  _Source({this.supported = true});
  @override
  final bool supported;
  int opens = 0, closes = 0;
  Uri? url;
  late void Function() opened, error;
  late void Function(String, String, String) message;
  @override
  void open(
    Uri url, {
    required void Function() onOpen,
    required void Function(String, String, String) onMessage,
    required void Function() onError,
  }) {
    opens++;
    this.url = url;
    opened = onOpen;
    error = onError;
    message = onMessage;
  }

  @override
  void close() {
    closes++;
  }

  void hint(String id) => message('changes', jsonEncode(_body(id)), id);
}

Map<String, dynamic> _body(String cursor) => {
  'cursor': cursor,
  'epoch': 'test',
  'revision': 1,
  'preferencesRevision': 0,
  'reset': false,
  'preferencesChanged': false,
  'changes': [
    {
      'resources': {
        'boxes': [1],
      },
    },
  ],
};
void main() {
  final url = Uri.parse('https://localhost/api/v1/changes/events');
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('one source, terminal failures cancel native retry, stale callbacks are ignored', () {
    final source = _Source();
    final stream = SharedChangeStream(url, source);
    addTearDown(stream.dispose);
    stream.start();
    stream.start();
    expect(source.opens, 1);
    source.opened();
    expect(stream.state, SharedStreamState.open);
    final oldMessage = source.message;
    source.hint('received-1');
    expect(stream.lastReceivedId, 'received-1');
    source.error();
    expect(stream.state, SharedStreamState.failed);
    expect(source.closes, 1);
    oldMessage('changes', jsonEncode(_body('late')), 'late');
    expect(stream.lastReceivedId, 'received-1');
    stream.start();
    expect(source.opens, 2);
    stream.stop(clearReceived: true);
    expect(stream.lastReceivedId, isNull);
  });
  test(
    'cancelling from the connecting signal does not create a late source',
    () {
      final source = _Source();
      final stream = SharedChangeStream(url, source);
      stream.addListener(() {
        if (stream.state == SharedStreamState.connecting) stream.stop();
      });
      stream.start();
      expect(stream.state, SharedStreamState.closed);
      expect(source.opens, 0);
      stream.dispose();
    },
  );
  test('received ID does not acknowledge outstanding or failed authoritative reads', () async {
    final source = _Source();
    final stream = SharedChangeStream(url, source);
    final read = Completer<void>();
    final refresh = SharedRefreshController(
      queryChanges: ({since}) async =>
          SharedChangeQuery(cursor: 'read-1', body: _body('read-1')),
    );
    addTearDown(stream.dispose);
    addTearDown(refresh.dispose);
    refresh.watch(
      dependencies: () => {'boxes': null},
      isVisible: () => true,
      refresh: (_) => read.future,
    );
    stream.start();
    source.opened();
    source.hint('transport-99');
    expect(refresh.appliedCursor, isNull);
    final pending = refresh.reconcile();
    await Future<void>.delayed(Duration.zero);
    expect(refresh.appliedCursor, isNull);
    expect(stream.lastReceivedId, 'transport-99');
    read.completeError(StateError('Read failed'));
    await expectLater(pending, throwsStateError);
    expect(refresh.appliedCursor, isNull);
  });
  test(
    'malformed or oversized frames close the source without applying a hint',
    () {
      for (final data in ['{', jsonEncode(_body('different')), 'x' * 65537]) {
        final source = _Source();
        final stream = SharedChangeStream(url, source);
        stream.start();
        source.message('changes', data, 'id');
        expect(stream.state, SharedStreamState.failed);
        expect(stream.lastReceivedId, isNull);
        stream.dispose();
      }
    },
  );
  test(
    'auth-required closes once and unsupported platforms never open a source',
    () {
      final source = _Source();
      final stream = SharedChangeStream(url, source);
      stream.start();
      source.message('auth-required', '{}', '');
      expect(stream.state, SharedStreamState.authRequired);
      expect(source.closes, 1);
      stream.dispose();
      final unsupported = _Source(supported: false);
      final fallback = SharedChangeStream(url, unsupported);
      fallback.start();
      expect(fallback.state, SharedStreamState.unsupported);
      expect(unsupported.opens, 0);
      fallback.dispose();
      expect(
        () => SharedChangeStream(url.replace(query: 'token=bad'), _Source()),
        throwsArgumentError,
      );
    },
  );

  testWidgets(
    'home delivers SSE wakeups to targeted refresh and skips idle polling while open',
    (tester) async {
      final source = _Source();
      var revision = 0;
      final reads = <String, int>{};
      final api = SharedApiClient(
        Uri.parse('https://localhost'),
        MockClient((request) async {
          final path = request.url.path;
          reads.update(path, (n) => n + 1, ifAbsent: () => 1);
          if (path == '/api/v1/auth/session') {
            return http.Response(
              jsonEncode({
                'user': {'username': 'carer', 'role': 'caregiver'},
                'csrfToken': 'csrf',
              }),
              200,
            );
          }
          if (path == '/api/v1/changes') {
            if (request.url.queryParameters['since'] == 'c$revision') {
              return http.Response(
                '',
                304,
                headers: {'x-shared-care-cursor': 'c$revision'},
              );
            }
            return http.Response(
              jsonEncode(
                _body('c$revision')
                  ..['reset'] = request.url.queryParameters['since'] == null,
              ),
              200,
            );
          }
          return http.Response(
            jsonEncode(switch (path) {
              '/api/v1/boxes' => {
                'boxes': [
                  {'id': 1, 'name': 'Box $revision', 'status': 'active'},
                ],
              },
              '/api/v1/animals' => {'animals': []},
              '/api/v1/reminders' => {'reminders': []},
              '/api/v1/auth/preferences' => {'preferences': {}},
              _ => {},
            }),
            200,
          );
        }),
        eventSource: source,
      );
      await tester.pumpWidget(SharedCareApp(api: api));
      await tester.pumpAndSettle();
      expect(source.opens, 1);
      expect(source.url, url);
      source.opened();
      source.hint('c0');
      await tester.pumpAndSettle();
      final before = Map.of(reads);
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(reads, before);
      revision++;
      source.hint('c1');
      await tester.pumpAndSettle();
      expect(find.text('Box 1'), findsWidgets);
      expect(reads['/api/v1/boxes'], before['/api/v1/boxes']! + 1);
      expect(reads['/api/v1/animals'], before['/api/v1/animals']);
      source.error();
      await tester.pumpAndSettle();
      final afterFailure = reads['/api/v1/changes']!;
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(reads['/api/v1/changes'], afterFailure + 1);
      expect(source.opens, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(source.opens, 2);
      source.opened();
      source.message('auth-required', '{}', '');
      await tester.pumpAndSettle();
      expect(api.session, isNull);
      expect(find.byKey(const Key('shared-login')), findsOneWidget);
      final opens = source.opens;
      await tester.pump(const Duration(seconds: 45));
      await tester.pumpAndSettle();
      expect(source.opens, opens);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
