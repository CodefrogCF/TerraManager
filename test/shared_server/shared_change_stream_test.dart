import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/app/shared_server_api.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/http/session_authenticator.dart';
import 'package:terramanager/shared_server/changes/application/committed_changes.dart';

import '../helpers/test_database_helper.dart';

class _Events {
  _Events(this.client, this.response) {
    response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.isEmpty) {
              if (_data.isNotEmpty) {
                events.add({
                  'event': _event,
                  'id': _id,
                  'data': jsonDecode(_data.join('\n')),
                });
                _data.clear();
                _event = 'message';
                _id = '';
                _wake();
              }
            } else if (line.startsWith('event: ')) {
              _event = line.substring(7);
            } else if (line.startsWith('id: ')) {
              _id = line.substring(4);
            } else if (line.startsWith('data: ')) {
              _data.add(line.substring(6));
            }
          },
          onDone: () {
            ended = true;
            _wake();
          },
          onError: (Object error) {
            ended = true;
            _wake();
          },
        );
  }
  final HttpClient client;
  final HttpClientResponse response;
  final events = <Map<String, dynamic>>[];
  final _data = <String>[];
  String _event = 'message', _id = '';
  bool ended = false;
  Completer<void>? _signal;
  void _wake() {
    _signal?.complete();
    _signal = null;
  }

  Future<Map<String, dynamic>> next() async {
    while (events.isEmpty) {
      if (ended) throw StateError('Stream ended before event.');
      _signal ??= Completer<void>();
      await _signal!.future.timeout(const Duration(seconds: 3));
    }
    return events.removeAt(0);
  }

  void close() => client.close(force: true);
}

void main() {
  late TestDatabaseHelper helper;
  late SharedServerApi api;
  late HttpServer server;
  late CareSession admin;
  final streams = <_Events>[];
  Future<void> settled(int expected) async {
    final end = DateTime.now().add(const Duration(seconds: 3));
    while (api.changeStreams.activeConnections != expected &&
        DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(api.changeStreams.activeConnections, expected);
  }

  Future<_Events> open({CareSession? session, String? after}) async {
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/api/v1/changes/events'),
    );
    request.headers.set(
      'Cookie',
      '${SessionAuthenticator.cookieName}=${(session ?? admin).token}',
    );
    if (after != null) request.headers.set('Last-Event-ID', after);
    final response = await request.close();
    expect(response.statusCode, 200);
    final stream = _Events(client, response);
    streams.add(stream);
    return stream;
  }

  Future<(int, Map<String, dynamic>, HttpHeaders)> call(
    String method,
    String path, {
    bool authorized = true,
    Map<String, String> headers = const {},
    Map<String, Object?>? body,
    Uint8List? bytes,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:${server.port}$path'),
      );
      if (authorized) {
        request.headers.set(
          'Cookie',
          '${SessionAuthenticator.cookieName}=${admin.token}',
        );
        request.headers.set('X-CSRF-Token', admin.csrfToken);
      }
      headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      if (bytes != null) {
        request.headers.contentType = ContentType.parse(
          'application/vnd.terramanager.backup+zip',
        );
        request.add(bytes);
      }
      final response = await request.close();
      final data = await response.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      return (
        response.statusCode,
        bytes != null || path == '/api/v1/admin/backups'
            ? {'bytes': data}
            : jsonDecode(utf8.decode(data)) as Map<String, dynamic>,
        response.headers,
      );
    } finally {
      client.close(force: true);
    }
  }

  String cursor([CareSession? session]) {
    final who = session ?? admin;
    return api.changes.cursor(
      accountKey: '${who.account.id}.${who.account.auditId}',
      role: who.account.role.name,
      preferencesRevision: helper.accounts.preferencesRevision(who.account.id),
    );
  }

  setUp(() async {
    helper = await TestDatabaseHelper.create(prefix: 'tm-sse-');
    final account = await helper.accounts.createInitialAdministrator(
      'administrator',
      'secure administrator password',
    );
    admin = helper.accounts.createSession(account);
    api = SharedServerApi(
      database: helper.database,
      accounts: helper.accounts,
      publicUrl: Uri.parse('https://terramanager.test'),
      changes: CommittedChanges(capacity: 3),
    );
    server = await api.serve();
  });
  tearDown(() async {
    for (final s in streams) {
      s.close();
    }
    streams.clear();
    await server.close(force: true);
    await settled(0);
    await helper.cleanup();
  });

  test('stream admission enforces cookie, origin, fetch site and credential-free URL', () async {
    expect(
      (await call('GET', '/api/v1/changes/events', authorized: false)).$1,
      401,
    );
    expect(
      (await call(
        'GET',
        '/api/v1/changes/events',
        headers: {'Origin': 'https://evil.test'},
      )).$1,
      403,
    );
    expect(
      (await call(
        'GET',
        '/api/v1/changes/events',
        headers: {'Sec-Fetch-Site': 'cross-site'},
      )).$1,
      403,
    );
    expect(
      (await call('GET', '/api/v1/changes/events?token=forbidden')).$1,
      400,
    );
    expect(
      (await call(
        'GET',
        '/api/v1/changes/events',
        headers: {'Last-Event-ID': 'a' * 201},
      )).$1,
      400,
    );
    final stream = await open();
    expect(stream.response.headers.contentType!.mimeType, 'text/event-stream');
    expect(
      stream.response.headers.value('cache-control'),
      contains('no-store'),
    );
    expect(stream.response.headers.value('vary'), 'Cookie');
    final event = await stream.next();
    expect(event['data']['reset'], true);
    expect(event['id'], cursor());
    expect(jsonEncode(event), isNot(contains(admin.token)));
    expect(jsonEncode(event), isNot(contains(admin.csrfToken)));
  });
  test('committed HTTP command sends minimal hints immediately while stream stays open', () async {
    final stream = await open(after: cursor());
    final result = await call(
      'POST',
      '/api/v1/boxes',
      body: {'name': 'PRIVATE BOX NAME'},
    );
    expect(result.$1, 201);
    final event = await stream.next();
    expect(event['data']['reset'], false);
    expect(event['data']['changes'].single['resources']['boxes'], [
      result.$2['box']['id'],
    ]);
    expect(jsonEncode(event), isNot(contains('PRIVATE BOX NAME')));
    expect(stream.ended, false);
    final revision = api.changes.revision;
    expect(
      (await call('POST', '/api/v1/boxes', body: {'widthCm': -1})).$1,
      400,
    );
    expect(api.changes.revision, revision);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(stream.events, isEmpty);
  });
  test('Last-Event-ID replays bounded history and resets foreign, expired or future cursors', () async {
    final before = cursor();
    api.changes.publish({
      'animals': [1],
      'audit': null,
    });
    api.changes.publish({
      'boxes': [2],
    });
    final stream = await open(after: before);
    expect((await stream.next())['data']['changes'], hasLength(2));
    for (final entry in {
      before.replaceFirst(':0:', ':99:'): 'future_cursor',
      api.changes.cursor(
        accountKey: 'different.audience',
        role: 'caregiver',
        preferencesRevision: 0,
      ): 'foreign_cursor',
      'invalid': 'invalid_cursor',
    }.entries) {
      final other = await open(after: entry.key);
      final data = (await other.next())['data'];
      expect(data['reset'], true);
      expect(data['reason'], entry.value);
      other.close();
    }
    for (var i = 0; i < 4; i++) {
      api.changes.publish({
        'animals': [i],
      });
    }
    final expired = await open(after: before);
    final event = await expired.next();
    expect(event['data']['reason'], 'expired_cursor');
    expect(event['data']['changes'], isEmpty);
  });
  test('preference notifications are private and audit hints are administrator-only', () async {
    final account = await helper.accounts.createAccount(
      'caregiver',
      'secure caregiver password',
      CareRole.caregiver,
    );
    final user = helper.accounts.createSession(account);
    final owner = await open(after: cursor());
    final other = await open(session: user, after: cursor(user));
    helper.accounts.updatePreferences(admin.account.id, {'language': 'german'});
    final event = await owner.next();
    expect(event['data']['preferencesChanged'], true);
    expect(jsonEncode(event), isNot(contains('german')));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(other.events, isEmpty);
    api.changes.publish({
      'animals': [7],
      'audit': null,
    });
    expect(
      (await owner.next())['data']['changes'].single['resources'],
      contains('audit'),
    );
    expect(
      (await other.next())['data']['changes'].single['resources'],
      isNot(contains('audit')),
    );
  });
  test('revocation terminates subscription immediately without another collection hint', () async {
    final stream = await open();
    await stream.next();
    helper.accounts.revokeSession(admin.token);
    expect((await stream.next())['event'], 'auth-required');
    await settled(0);
    api.changes.publish({
      'animals': [99],
    });
    expect(stream.events, isEmpty);
    expect((await call('GET', '/api/v1/changes/events')).$1, 401);
  });
  test(
    'session expiration terminates an idle stream at its deadline',
    () async {
      final short = helper.accounts.createSession(
        admin.account,
        now: DateTime.now()
            .toUtc()
            .subtract(AccountStore.sessionLifetime)
            .add(const Duration(seconds: 2)),
      );
      final stream = await open(session: short);
      await stream.next();
      expect((await stream.next())['event'], 'auth-required');
      await settled(0);
    },
  );
  test('account deactivation revokes an already open stream', () async {
    final account = await helper.accounts.createAccount(
      'caregiver',
      'secure caregiver password',
      CareRole.caregiver,
    );
    final stream = await open(session: helper.accounts.createSession(account));
    await stream.next();
    await helper.accounts.updateAccount(
      account.id,
      active: false,
      actor: admin.account,
    );
    expect((await stream.next())['event'], 'auth-required');
    await settled(0);
  });
  test('per-account limit rejects excess streams and repeated idle disconnects release slots', () async {
    for (var i = 0; i < 8; i++) {
      final stream = await open();
      await stream.next();
    }
    await settled(8);
    expect((await call('GET', '/api/v1/changes/events')).$1, 429);
    for (final stream in streams) {
      stream.close();
    }
    await settled(0);
    for (var i = 0; i < 24; i++) {
      final stream = await open();
      await stream.next();
      stream.close();
      await settled(0);
    }
  });
  test('global connection limit is shared across accounts', () async {
    final sessions = <CareSession>[admin];
    for (var i = 0; i < 4; i++) {
      final account = await helper.accounts.createAccount(
        'caregiver$i',
        'secure caregiver password',
        CareRole.caregiver,
      );
      sessions.add(helper.accounts.createSession(account));
    }
    for (final session in sessions.take(4)) {
      for (var i = 0; i < 8; i++) {
        final stream = await open(session: session);
        await stream.next();
      }
    }
    await settled(32);
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/api/v1/changes/events'),
      );
      request.headers.set(
        'Cookie',
        '${SessionAuthenticator.cookieName}=${sessions.last.token}',
      );
      final response = await request.close();
      expect(response.statusCode, 429);
      expect(response.headers.value('Retry-After'), '15');
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
    for (final stream in streams) {
      stream.close();
    }
    await settled(0);
  });
  test('oversized retained replay collapses into a small reset frame', () async {
    // Two large domain sets per commit overflow 64 KiB without leaking records.
    final feed = CommittedChanges();
    await server.close(force: true);
    api = SharedServerApi(
      database: helper.database,
      accounts: helper.accounts,
      publicUrl: Uri.parse('https://terramanager.test'),
      changes: feed,
    );
    server = await api.serve();
    final before = cursor();
    for (var i = 0; i < 100; i++) {
      feed.publish({
        'animals': List.generate(128, (n) => n + 100000),
        'boxes': List.generate(128, (n) => n + 200000),
      });
    }
    final stream = await open(after: before);
    final event = await stream.next();
    expect(event['data']['reset'], true);
    expect(event['data']['reason'], 'replay_too_large');
    expect(utf8.encode(jsonEncode(event)).length, lessThan(1024));
  });
  test('open subscription does not block export/restore; only successful replacement resets', () async {
    final stream = await open(after: cursor());
    final backup = await call('GET', '/api/v1/admin/backups');
    expect(backup.$1, 200);
    final headers = {
      'X-Safety-Token': backup.$3.value('X-Safety-Token')!,
      'X-Restore-Confirmation': 'replace-shared-collection',
    };
    expect(
      (await call(
        'POST',
        '/api/v1/admin/backups/restore',
        bytes: Uint8List.fromList([1, 2, 3]),
        headers: headers,
      )).$1,
      400,
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(stream.events, isEmpty);
    expect(
      (await call(
        'POST',
        '/api/v1/admin/backups/restore',
        bytes: Uint8List.fromList(backup.$2['bytes'] as List<int>),
        headers: headers,
      )).$1,
      200,
    );
    expect((await stream.next())['data']['reason'], 'epoch_changed');
    expect(stream.ended, false);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
