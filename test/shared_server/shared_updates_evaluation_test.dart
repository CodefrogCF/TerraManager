import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/evaluation/shared_updates/change_feed.dart';
import '../../tool/evaluation/shared_updates/lab_server.dart';

void main() {
  test('bounded feed resets old, future and foreign cursors without leaking record values', () async {
    final feed = EvaluationChangeFeed(capacity: 2, epoch: 'test');
    addTearDown(feed.close);
    feed.publish();
    feed.publish();
    feed.publish();
    expect(feed.since('test:0')['reset'], isTrue);
    expect(feed.since('test:4')['reset'], isTrue);
    expect(feed.since('other:3')['reset'], isTrue);
    expect(feed.since('malformed')['reset'], isTrue);
    final changes = feed.since('test:1');
    expect(changes['reset'], isFalse);
    expect(changes['events'], hasLength(2));
    expect(feed.since(feed.cursor)['events'], isEmpty);
    final before = feed.cursor;
    feed.reset();
    expect(feed.since(before)['reset'], isTrue);
  });

  late UpdateEvaluationLab lab;
  late HttpClient client;
  late String cookie;
  late String csrf;
  late Directory scratch;

  Future<(int, Map<String, dynamic>?, String?)> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool csrfValid = true,
    String? origin,
    String? etag,
  }) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${lab.server.port}$path'),
    );
    if (authenticated) request.headers.set('Cookie', cookie);
    if (etag != null) request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
    if (method == 'POST') {
      request.headers.set(
        'Origin',
        origin ?? 'http://localhost:${lab.server.port}',
      );
      request.headers.set('X-CSRF-Token', csrfValid ? csrf : 'wrong');
      if (path == '/api/v1/feedings') {
        request.headers.set(
          'Idempotency-Key',
          '00000000-0000-4000-8000-000000000001',
        );
      }
    } else if (origin != null) {
      request.headers.set('Origin', origin);
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return (
      response.statusCode,
      text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>,
      response.headers.value('set-cookie')?.split(';').first,
    );
  }

  group('disposable API evaluation lab', () {
    test('LAN binding requires an explicit HTTPS origin', () async {
      final parent = await Directory.systemTemp.createTemp('tm186-bind-test-');
      try {
        await expectLater(
          UpdateEvaluationLab.start(
            scratchParent: parent,
            assets: Directory('tool/evaluation/shared_updates/web'),
            bind: '0.0.0.0',
          ),
          throwsArgumentError,
        );
      } finally {
        await parent.delete();
      }
    });
    setUp(() async {
      scratch = await Directory.systemTemp.createTemp('tm186-tests-');
      lab = await UpdateEvaluationLab.start(
        scratchParent: scratch,
        assets: Directory('tool/evaluation/shared_updates/web'),
        animalCount: 2,
        historyPerAnimal: 1,
      );
      client = HttpClient();
      cookie = '';
      csrf = '';
      final credentials = jsonDecode(
        await File('${lab.directory.path}/credentials.json').readAsString(),
      ) as Map<String, dynamic>;
      final login = await call(
        'POST',
        '/api/v1/auth/login',
        authenticated: false,
        body: {
          'username': credentials['username'],
          'password': credentials['password'],
        },
      );
      expect(login.$1, 200);
      cookie = login.$3!;
      csrf = login.$2!['csrfToken'] as String;
    });
    tearDown(() async {
      client.close(force: true);
      await lab.close();
      await scratch.delete();
    });

    test('fixture is isolated and all notification endpoints require a valid session', () async {
      for (final path in [
        '/evaluation/state',
        '/evaluation/changes',
        '/evaluation/events',
        '/evaluation/socket',
      ]) {
        expect((await call('GET', path, authenticated: false)).$1, 401);
      }
      expect((await call('GET', '/evaluation/state')).$2!['fixture'], {
        'animals': 2,
        'boxes': 5,
        'feedings': 2,
      });
      expect(
        (await call(
          'GET',
          '/evaluation/state',
          origin: 'https://other.example',
        )).$1,
        403,
      );
    });

    test('only a successful real Feeding write publishes; rejected writes keep the cursor', () async {
      final cursor = lab.feed.cursor;
      final body = {
        'animalIds': [1],
        'fedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };
      expect(
        (await call(
          'POST',
          '/api/v1/feedings',
          body: body,
          csrfValid: false,
        )).$1,
        403,
      );
      expect(lab.feed.cursor, cursor);
      expect(
        (await call('POST', '/api/v1/feedings', body: {'animalIds': []})).$1,
        400,
      );
      expect(lab.feed.cursor, cursor);
      final published = lab.feed.changes.first;
      expect((await call('POST', '/api/v1/feedings', body: body)).$1, 201);
      await published.timeout(const Duration(seconds: 5));
      expect(lab.feed.revision, 1);
      final histories = (await call('GET', '/api/v1/animals/1/feedings')).$2!;
      expect(histories['feedings'], hasLength(2));
      final update = await call(
        'GET',
        '/evaluation/changes?after=${Uri.encodeComponent(cursor)}',
      );
      expect(update.$1, 200);
      expect(update.$2!['events'], hasLength(1));
      expect(
        (await call(
          'GET',
          '/evaluation/changes?after=${Uri.encodeComponent(lab.feed.cursor)}',
        )).$1,
        200,
      );
      expect(
        (await call(
          'GET',
          '/evaluation/changes?after=${Uri.encodeComponent(lab.feed.cursor)}',
          etag: lab.feed.etag,
        )).$1,
        304,
      );
    });

    test('revoked sessions cannot retrieve a waiting change response', () async {
      final pending = call(
        'GET',
        '/evaluation/changes?wait=1&after=${Uri.encodeComponent(lab.feed.cursor)}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((await call('POST', '/api/v1/auth/logout')).$1, 200);
      lab.feed.publish();
      expect((await pending.timeout(const Duration(seconds: 5))).$1, 401);
    });

    test('long polling wakes on a committed API write and returns a bounded change hint', () async {
      final pending = call(
        'GET',
        '/evaluation/changes?wait=1&after=${Uri.encodeComponent(lab.feed.cursor)}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await call(
        'POST',
        '/api/v1/feedings',
        body: {
          'animalIds': [1],
          'fedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        },
      );
      expect(
        (await pending.timeout(const Duration(seconds: 5))).$2!['revision'],
        1,
      );
    });

    test(
      'WebSocket uses the same session and detects a foreign cursor',
      () async {
        final socket = await WebSocket.connect(
          'ws://127.0.0.1:${lab.server.port}/evaluation/socket?after=foreign:0',
          headers: {
            'Cookie': cookie,
            'Origin': 'http://localhost:${lab.server.port}',
          },
        );
        final update =
            jsonDecode(await socket.first as String) as Map<String, dynamic>;
        expect(update['reset'], isTrue);
        await socket.close();
      },
    );

    test('SSE sends replay and event IDs over an authenticated streaming response', () async {
      lab.feed.publish();
      final request = await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${lab.server.port}/evaluation/events?after=${Uri.encodeComponent('${lab.feed.epoch}:0')}',
        ),
      );
      request.headers.set('Cookie', cookie);
      final response = await request.close();
      expect(response.headers.contentType!.mimeType, 'text/event-stream');
      final lines = response
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final data = await lines
          .firstWhere((line) => line.startsWith('data: '))
          .timeout(const Duration(seconds: 5));
      final payload = jsonDecode(data.substring(6)) as Map<String, dynamic>;
      expect(payload['revision'], 1);
      expect(payload['events'], hasLength(1));
    });
  });
}
