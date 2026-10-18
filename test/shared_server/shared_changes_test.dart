import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:terramanager/shared_server/app/shared_server_api.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/changes/application/committed_changes.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/http/session_authenticator.dart';
import 'package:terramanager/shared_server/collection/infrastructure/http/care_api.dart';

import '../helpers/test_database_helper.dart';

class _Reply {
  _Reply(this.status, this.bytes, this.headers);
  final int status;
  final Uint8List bytes;
  final HttpHeaders headers;
  Map<String, dynamic> get json =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}

class _ObservedChanges extends CommittedChanges {
  void Function()? onPublish;
  @override
  void publish(Map<String, Iterable<int>?> resources) {
    if (resources.isNotEmpty) onPublish?.call();
    super.publish(resources);
  }
}

void main() {
  late TestDatabaseHelper helper;
  late SharedServerApi api;
  late HttpServer server;
  late HttpClient client;
  late CareSession session;
  Future<_Reply> call(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
    CareSession? asSession,
    bool authorized = true,
    Uint8List? archive,
  }) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );
    if (authorized) {
      final actor = asSession ?? session;
      request.headers.set(
        'Cookie',
        '${SessionAuthenticator.cookieName}=${actor.token}',
      );
      request.headers.set('X-CSRF-Token', actor.csrfToken);
    }
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    if (archive != null) {
      request.headers.contentType = ContentType.parse(
        'application/vnd.terramanager.backup+zip',
      );
      request.headers.set(
        'X-Restore-Confirmation',
        'replace-shared-collection',
      );
      request.add(archive);
    }
    final response = await request.close();
    final bytes = BytesBuilder();
    await for (final chunk in response) {
      bytes.add(chunk);
    }
    return _Reply(response.statusCode, bytes.takeBytes(), response.headers);
  }

  Future<Map<String, dynamic>> changes([String? since]) async => (await call(
    'GET',
    '/api/v1/changes${since == null ? '' : '?since=${Uri.encodeQueryComponent(since)}'}',
  )).json;
  Future<String> cursor() async => (await changes())['cursor'] as String;
  Future<int> box([String name = 'Box']) async {
    final result = await call('POST', '/api/v1/boxes', body: {'name': name});
    expect(result.status, 201, reason: result.json.toString());
    return result.json['box']['id'] as int;
  }

  Future<int> animal(int boxId) async {
    final result = await call(
      'POST',
      '/api/v1/animals',
      body: {
        'boxId': boxId,
        'commonName': 'Animal',
        'latinName': 'Example',
        'tempMin': 22,
        'tempMax': 28,
        'humidityMin': 40,
        'humidityMax': 60,
      },
    );
    expect(result.status, 201, reason: result.json.toString());
    return result.json['animal']['id'] as int;
  }

  setUp(() async {
    helper = await TestDatabaseHelper.create(prefix: 'tm-changes-');
    final admin = await helper.accounts.createInitialAdministrator(
      'admin',
      'secure admin password 123',
    );
    session = helper.accounts.createSession(admin);
    client = HttpClient();
    api = SharedServerApi(
      database: helper.database,
      accounts: helper.accounts,
      changes: _ObservedChanges(),
      publicUrl: Uri.parse('http://127.0.0.1'),
    );
    server = await api.serve();
  });
  tearDown(() async {
    await server.close(force: true);
    client.close(force: true);
    await helper.cleanup();
  });

  test('queries authenticate before 304, check origin, and expose safe conditional headers', () async {
    final start = await cursor();
    final path = '/api/v1/changes?since=${Uri.encodeQueryComponent(start)}';
    final unchanged = await call(
      'GET',
      path,
      headers: {'If-None-Match': 'W/"$start"'},
    );
    expect(unchanged.status, 304);
    expect(unchanged.bytes, isEmpty);
    expect(unchanged.headers.value('Vary'), 'Cookie');
    expect(unchanged.headers.value('Cache-Control'), 'private, no-store');
    expect(
      (await call(
        'GET',
        path,
        authorized: false,
        headers: {'If-None-Match': '"$start"'},
      )).status,
      401,
    );
    expect(
      (await call(
        'GET',
        path,
        headers: {'Origin': 'https://other.test'},
      )).status,
      403,
    );
    final created = await call(
      'POST',
      '/api/v1/boxes',
      body: {'name': 'PRIVATE NAME'},
    );
    final updated = await call(
      'GET',
      path,
      headers: {'If-None-Match': '"$start"'},
    );
    expect(updated.status, 200);
    expect(updated.json['revision'], 1);
    expect(utf8.decode(updated.bytes), isNot(contains('PRIVATE NAME')));
    final list = await call('GET', '/api/v1/boxes');
    expect(
      list.headers.value(CommittedChanges.beforeHeader),
      created.headers.value(CommittedChanges.cursorHeader),
    );
    expect(
      list.headers.value(CommittedChanges.cursorHeader),
      list.headers.value(CommittedChanges.beforeHeader),
    );
  });
  test(
    'concurrent commits are advertised once each and moves include both Boxes',
    () async {
      final start = await cursor();
      final boxes = await Future.wait([box('A'), box('B')]);
      expect((await changes(start))['changes'], hasLength(2));
      final id = await animal(boxes.first);
      final before = await cursor();
      expect(
        (await call(
          'POST',
          '/api/v1/animals/$id/move',
          body: {'boxId': boxes.last},
        )).status,
        200,
      );
      final hint =
          ((await changes(before))['changes'] as List).single['resources']
              as Map;
      expect(hint['animals'], [id]);
      expect(hint['boxes'], containsAll(boxes));
    },
  );
  test('publication sees the external committed database and read races change the cursor fence', () async {
    await server.close(force: true);
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    final feed = api.changes as _ObservedChanges;
    feed.onPublish = () {
      final observer = sqlite.sqlite3.open(helper.collectionDbFile.path);
      try {
        expect(
          observer.select('SELECT COUNT(*) AS n FROM boxes').single['n'],
          1,
        );
      } finally {
        observer.close();
      }
    };
    var race = false;
    server = await CareApi(
      database: helper.database,
      authenticator: api.sessions,
      changes: feed,
      audit: (request, status, body, replayed) async {
        entered.complete();
        await release.future;
      },
      cursorForRequest: (request) {
        final cursor = feed.cursor(
          accountKey: '${session.account.id}.${session.account.auditId}',
          role: 'administrator',
          preferencesRevision: 0,
        );
        if (request.method == 'GET' && !race) {
          race = true;
          scheduleMicrotask(
            () => feed.publish({
              'boxes': [1],
            }),
          );
        }
        return cursor;
      },
    ).serve();
    final pending = call('POST', '/api/v1/boxes', body: {'name': 'Committed'});
    await entered.future;
    expect(feed.revision, 0);
    release.complete();
    expect((await pending).status, 201);
    expect(feed.revision, 1);
    final read = await call('GET', '/api/v1/boxes');
    expect(
      read.headers.value(CommittedChanges.beforeHeader),
      isNot(read.headers.value(CommittedChanges.cursorHeader)),
    );
  });
  test(
    'grouped Feedings publish once; replay and rollback publish nothing',
    () async {
      final b = await box();
      final a = await animal(b);
      final second = await animal(b);
      final before = await cursor();
      const key = '11111111-1111-4111-8111-111111111111';
      final body = {
        'animalIds': [a, second],
        'fedAt': '2026-09-26T10:00:00Z',
      };
      for (var i = 0; i < 2; i++) {
        expect(
          (await call(
            'POST',
            '/api/v1/feedings',
            body: body,
            headers: {'Idempotency-Key': key},
          )).status,
          201,
        );
      }
      final entries = (await changes(before))['changes'] as List;
      expect(entries, hasLength(1));
      expect(entries.single['resources']['feedingHistories'], [a, second]);
      final revision = api.changes.revision;
      await helper.database.customStatement(
        "CREATE TRIGGER fail_audit BEFORE INSERT ON shared_audit_events BEGIN SELECT RAISE(ABORT, 'audit unavailable'); END",
      );
      final failed = await call(
        'POST',
        '/api/v1/feedings',
        body: body,
        headers: {'Idempotency-Key': '22222222-2222-4222-8222-222222222222'},
      );
      expect(failed.status, greaterThanOrEqualTo(400));
      expect(api.changes.revision, revision);
      expect(
        await helper.database.select(helper.database.feedingEvents).get(),
        hasLength(2),
      );
      await helper.database.customStatement('DROP TRIGGER fail_audit');
      expect(
        (await call(
          'POST',
          '/api/v1/feedings',
          body: body,
          headers: {'Idempotency-Key': '22222222-2222-4222-8222-222222222222'},
        )).status,
        201,
      );
      expect(api.changes.revision, revision + 1);
      final feeding =
          (await helper.database.select(helper.database.feedingEvents).get())
              .first;
      for (final method in ['PUT', 'DELETE']) {
        final cursorBefore = await cursor();
        final reply = await call(
          method,
          '/api/v1/feedings/${feeding.id}',
          body: method == 'PUT' ? {'fedAt': '2026-09-26T11:00:00Z'} : null,
        );
        expect(reply.status, 200);
        final hints = (await changes(cursorBefore))['changes'] as List;
        expect(hints.single['resources']['feedingHistories'], [
          feeding.animalId,
        ]);
      }
    },
  );
  test(
    'invalid writes, CSRF failure and conflicts never advance the revision',
    () async {
      final before = api.changes.revision;
      expect(
        (await call('POST', '/api/v1/boxes', body: {'widthCm': -1})).status,
        400,
      );
      expect(
        (await call(
          'POST',
          '/api/v1/boxes',
          body: {'name': 'Denied'},
          headers: {'X-CSRF-Token': 'wrong'},
        )).status,
        403,
      );
      expect(
        (await call(
          'POST',
          '/api/v1/animals/999/restore',
          body: {'boxId': 1},
        )).status,
        404,
      );
      expect(api.changes.revision, before);
      final b = await box();
      final revision = api.changes.revision;
      expect(
        (await call(
          'PATCH',
          '/api/v1/boxes/$b',
          body: {'expectedRevision': 'stale', 'name': 'No'},
        )).status,
        409,
      );
      expect(api.changes.revision, revision);
    },
  );
  test('weights, shedding, pictures, primary selection, archive and deletion are covered', () async {
    final b = await box();
    final a = await animal(b);
    Future<void> mutate(
      String method,
      String path,
      Map<String, Object?>? body,
      String domain,
    ) async {
      final before = await cursor();
      final reply = await call(method, path, body: body);
      expect(
        reply.status,
        inInclusiveRange(200, 299),
        reason: reply.json.toString(),
      );
      final hints = (await changes(before))['changes'] as List;
      expect(hints, hasLength(1));
      expect(hints.single['resources'].containsKey(domain), true);
    }

    final weight = await call(
      'POST',
      '/api/v1/animals/$a/weights',
      body: {'weightGrams': 12.5},
    );
    await mutate(
      'PUT',
      '/api/v1/animals/$a/weights/${weight.json['weight']['id']}',
      {'weightGrams': 13.0, 'measuredAt': '2026-09-26T10:00:00Z'},
      'weightHistories',
    );
    final shed = await call(
      'POST',
      '/api/v1/animals/$a/shedding',
      body: {'notes': 'PRIVATE'},
    );
    await mutate(
      'DELETE',
      '/api/v1/animals/$a/shedding/${shed.json['shedding']['id']}',
      null,
      'sheddingHistories',
    );
    final before = await cursor();
    final pictureBody = {
      'fileName': 'picture.png',
      'mimeType': 'image/png',
      'dataBase64': base64Encode(
        image.encodePng(image.Image(width: 1, height: 1)),
      ),
    };
    const key = '33333333-3333-4333-8333-333333333333';
    final picture = await call(
      'POST',
      '/api/v1/animals/$a/pictures',
      body: pictureBody,
      headers: {'Idempotency-Key': key},
    );
    expect(picture.status, 201);
    await call(
      'POST',
      '/api/v1/animals/$a/pictures',
      body: pictureBody,
      headers: {'Idempotency-Key': key},
    );
    expect((await changes(before))['changes'], hasLength(1));
    final mediaId = picture.json['picture']['mediaId'];
    await mutate(
      'POST',
      '/api/v1/animals/$a/pictures/$mediaId/primary',
      null,
      'animalPictures',
    );
    await mutate(
      'DELETE',
      '/api/v1/animals/$a/pictures/$mediaId',
      null,
      'media',
    );
    await mutate('POST', '/api/v1/animals/$a/archive', {
      'reason': 'other',
    }, 'animals');
    await mutate('POST', '/api/v1/animals/$a/restore', {'boxId': b}, 'animals');
    await mutate('POST', '/api/v1/animals/$a/archive', {
      'reason': 'other',
    }, 'animals');
    await mutate('DELETE', '/api/v1/animals/$a', null, 'feedingHistories');
    await mutate('POST', '/api/v1/boxes/$b/archive', {
      'reason': 'other',
    }, 'boxes');
    await mutate('POST', '/api/v1/boxes/$b/restore', null, 'boxes');
    await mutate('POST', '/api/v1/boxes/$b/archive', {
      'reason': 'other',
    }, 'boxes');
    await mutate('DELETE', '/api/v1/boxes/$b', null, 'boxes');
  });
  test('preferences remain private, persistent and coalesced after successful updates', () async {
    final caregiver = await helper.accounts.createAccount(
      'caregiver',
      'secure caregiver password 123',
      CareRole.caregiver,
    );
    final other = helper.accounts.createSession(caregiver);
    final before = await cursor();
    final otherCursor =
        (await call('GET', '/api/v1/changes', asSession: other)).json['cursor']
            as String;
    final revision = api.changes.revision;
    for (var i = 0; i < 2; i++) {
      expect(
        (await call(
          'PATCH',
          '/api/v1/auth/preferences',
          body: {'language': 'german'},
        )).status,
        200,
      );
    }
    expect(helper.accounts.preferencesRevision(session.account.id), 1);
    expect(api.changes.revision, revision);
    expect((await changes(before))['preferencesChanged'], true);
    final otherState = await call(
      'GET',
      '/api/v1/changes?since=${Uri.encodeQueryComponent(otherCursor)}',
      asSession: other,
      headers: {'If-None-Match': '"$otherCursor"'},
    );
    expect(otherState.status, 304);
    final reopened = await AccountStore.open(helper.accountsDbFile);
    expect(reopened.preferencesRevision(session.account.id), 1);
    reopened.close();
    final raw = sqlite.sqlite3.open(helper.accountsDbFile.path);
    raw.execute(
      "CREATE TRIGGER fail_preferences BEFORE UPDATE ON account_preferences BEGIN SELECT RAISE(ABORT, 'failure'); END",
    );
    expect(
      (await call(
        'PATCH',
        '/api/v1/auth/preferences',
        body: {'language': 'english'},
      )).status,
      greaterThanOrEqualTo(400),
    );
    expect(helper.accounts.preferencesRevision(session.account.id), 1);
    raw.execute('DROP TRIGGER fail_preferences');
    raw.close();
  });
  test(
    'metadata primary-picture changes invalidate only the affected galleries',
    () async {
      final b = await box();
      final a = await animal(b);
      final pictureBody = {
        'fileName': 'picture.png',
        'mimeType': 'image/png',
        'dataBase64': base64Encode(
          image.encodePng(image.Image(width: 1, height: 1)),
        ),
      };
      final imageReply = await call(
        'POST',
        '/api/v1/animals/$a/pictures',
        body: pictureBody,
      );
      expect(imageReply.status, 201);
      final media = imageReply.json['picture']['mediaId'];
      for (var i = 0; i < 2; i++) {
        final opened =
            (await call('GET', '/api/v1/animals/$a')).json['animal'] as Map;
        final before = await cursor();
        final edited = await call(
          'PUT',
          '/api/v1/animals/$a',
          body: {
            'expectedRevision': opened['revision'],
            'boxId': b,
            'commonName': 'Changed $i',
            'showWeightOnDetail': false,
            'showSheddingOnDetail': false,
            'latinName': 'Example',
            'category': 'other',
            'tempMin': 22,
            'tempMax': 28,
            'humidityMin': 40,
            'humidityMax': 60,
            'pictureMediaId': null,
          },
        );
        expect(edited.status, 200, reason: edited.json.toString());
        final hints =
            ((await changes(before))['changes'] as List).single['resources']
                as Map;
        if (i == 0) {
          expect(hints['animalPictures'], [a]);
          expect(hints['media'], [media]);
        } else {
          expect(hints.containsKey('animalPictures'), false);
        }
      }
      final boxImage = await call(
        'POST',
        '/api/v1/boxes/$b/pictures',
        body: pictureBody,
      );
      expect(boxImage.status, 201);
      final opened = (await call('GET', '/api/v1/boxes/$b')).json['box'] as Map;
      final before = await cursor();
      expect(
        (await call(
          'PATCH',
          '/api/v1/boxes/$b',
          body: {
            'expectedRevision': opened['revision'],
            'pictureMediaId': null,
          },
        )).status,
        200,
      );
      final hints =
          ((await changes(before))['changes'] as List).single['resources']
              as Map;
      expect(hints['boxPictures'], [b]);
      expect(hints['media'], [boxImage.json['picture']['mediaId']]);
    },
  );
  test('legacy private preferences migrate without losing values', () async {
    final file = File('${helper.directory.path}/legacy-accounts.sqlite');
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute(
      'CREATE TABLE accounts (id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, role TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1)',
    );
    raw.execute(
      "INSERT INTO accounts VALUES (1,'legacy','unused','administrator',1)",
    );
    raw.execute(
      'CREATE TABLE account_preferences (account_id INTEGER PRIMARY KEY, preferences_json TEXT NOT NULL)',
    );
    raw.execute('INSERT INTO account_preferences VALUES (?,?)', [
      1,
      jsonEncode({'language': 'german'}),
    ]);
    raw.close();
    final migrated = await AccountStore.open(file);
    try {
      expect(migrated.preferences(1)['language'], 'german');
      expect(migrated.preferencesRevision(1), 0);
      migrated.updatePreferences(1, {'language': 'english'});
      expect(migrated.preferencesRevision(1), 1);
    } finally {
      migrated.close();
    }
  });
  test('successful restore rotates epoch once while failed restore keeps its cursor', () async {
    await box();
    await call(
      'PATCH',
      '/api/v1/auth/preferences',
      body: {'language': 'german'},
    );
    final before = await cursor();
    final backup = await call('GET', '/api/v1/admin/backups');
    final safety = backup.headers.value('X-Safety-Token')!;
    final epoch = api.changes.epoch;
    expect(
      (await call(
        'POST',
        '/api/v1/admin/backups/restore',
        archive: Uint8List.fromList([1, 2, 3]),
        headers: {'X-Safety-Token': safety},
      )).status,
      400,
    );
    expect(api.changes.epoch, epoch);
    expect(
      (await call(
        'POST',
        '/api/v1/admin/backups/restore',
        archive: backup.bytes,
        headers: {'X-Safety-Token': safety},
      )).status,
      200,
    );
    expect(api.changes.epoch, isNot(epoch));
    expect(api.changes.revision, 0);
    expect(helper.accounts.preferencesRevision(session.account.id), 1);
    expect(
      helper.accounts.preferences(session.account.id)['language'],
      'german',
    );
    expect((await changes(before))['reason'], 'epoch_changed');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
