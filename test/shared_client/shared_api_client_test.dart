import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';

void main() {
  const origin = 'https://192.168.1.117';
  final session = {
    'user': {'username': 'hagen', 'role': 'administrator'},
    'csrfToken': 'csrf-secret',
    'expiresAt': '2026-09-24T08:00:00Z',
  };

  test('two signed-in clients read the same server-owned Box', () async {
    final boxes = <Map<String, dynamic>>[];
    final requests = <http.Request>[];
    final backend = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(jsonEncode(session), 200);
      }
      if (request.url.path == '/api/v1/boxes' && request.method == 'POST') {
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        final box = {
          'id': 1,
          'qrId': 'new-server-qr',
          'status': 'active',
          'name': input['name'],
        };
        boxes.add(box);
        return http.Response(jsonEncode({'box': box}), 201);
      }
      if (request.url.path == '/api/v1/boxes') {
        return http.Response(jsonEncode({'boxes': boxes}), 200);
      }
      return http.Response('{}', 404);
    });
    final first = SharedApiClient(Uri.parse(origin), backend);
    final second = SharedApiClient(Uri.parse(origin), backend);

    await first.login('hagen', 'secret password');
    await second.login('hagen', 'secret password');
    final created = await first.createBox({'name': 'Room 2'});
    final seen = await second.boxes();

    expect(created['qrId'], 'new-server-qr');
    expect(seen.single['name'], 'Room 2');
    expect(requests.last.url.origin, origin);
    expect(
      requests
          .where(
            (request) =>
                request.method == 'POST' && request.url.path == '/api/v1/boxes',
          )
          .single
          .headers['X-CSRF-Token'],
      'csrf-secret',
    );
    first.close();
    second.close();
  });

  test('failed mutation never reports a created record', () async {
    final backend = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(jsonEncode(session), 200);
      }
      return http.Response(
        jsonEncode({
          'error': {'code': 'conflict', 'message': 'Box is archived.'},
        }),
        409,
      );
    });
    final client = SharedApiClient(Uri.parse(origin), backend);
    await client.login('hagen', 'secret password');

    await expectLater(
      client.updateBox(3, {'name': 'Changed'}),
      throwsA(
        isA<SharedApiException>().having(
          (error) => error.status,
          'status',
          409,
        ),
      ),
    );
    expect(client.connected, isTrue);
    client.close();
  });

  test(
    'connection loss blocks success and a later request reconnects',
    () async {
      var offline = false;
      final backend = MockClient((request) async {
        if (offline) throw http.ClientException('offline');
        if (request.url.path == '/api/v1/auth/session') {
          return http.Response(jsonEncode(session), 200);
        }
        return http.Response(jsonEncode({'boxes': []}), 200);
      });
      final client = SharedApiClient(Uri.parse(origin), backend);
      await client.restoreSession();
      expect(client.connected, isTrue);

      offline = true;
      await expectLater(
        client.boxes(),
        throwsA(isA<SharedConnectionException>()),
      );
      expect(client.connected, isFalse);
      expect(client.session, isNotNull);

      offline = false;
      expect(await client.boxes(), isEmpty);
      expect(client.connected, isTrue);
      client.close();
    },
  );

  test('unauthorized response clears the in-memory session', () async {
    final backend = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/session') {
        return http.Response(jsonEncode(session), 200);
      }
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'unauthorized',
            'message': 'Authentication required.',
          },
        }),
        401,
      );
    });
    final client = SharedApiClient(Uri.parse(origin), backend);
    await client.restoreSession();
    await expectLater(client.animals(), throwsA(isA<SharedApiException>()));
    expect(client.session, isNull);
    client.close();
  });

  test(
    'admin backup download supplies the token required for restore',
    () async {
      final archive = <int>[80, 75, 3, 4];
      http.Request? restoreRequest;
      final backend = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(jsonEncode(session), 200);
        }
        if (request.url.path == '/api/v1/admin/backups' &&
            request.method == 'GET') {
          return http.Response.bytes(
            archive,
            200,
            headers: {
              'x-safety-token': 'safety-token',
              'content-disposition':
                  'attachment; filename="TerraManager_Backup.tmbackup"',
            },
          );
        }
        if (request.url.path == '/api/v1/admin/backups/restore') {
          restoreRequest = request;
          return http.Response(jsonEncode({'restored': true}), 200);
        }
        return http.Response('{}', 404);
      });
      final client = SharedApiClient(Uri.parse(origin), backend);
      try {
        await client.login('hagen', 'secret password');
        final exported = await client.exportBackup();
        expect(exported.bytes, archive);
        expect(exported.fileName, 'TerraManager_Backup.tmbackup');
        await client.restoreBackup(exported.bytes, exported.safetyToken);
        expect(restoreRequest!.bodyBytes, archive);
        expect(restoreRequest!.headers['X-CSRF-Token'], 'csrf-secret');
        expect(restoreRequest!.headers['X-Safety-Token'], 'safety-token');
        expect(
          restoreRequest!.headers['X-Restore-Confirmation'],
          'replace-shared-collection',
        );
      } finally {
        client.close();
      }
    },
  );
}
