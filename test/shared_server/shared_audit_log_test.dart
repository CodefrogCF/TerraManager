import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/account_store.dart';
import 'package:terramanager/shared_server/audit_event.dart';
import 'package:terramanager/shared_server/collection_audit_log.dart';
import 'package:terramanager/shared_server/server_database.dart';
import 'package:terramanager/shared_server/shared_server_api.dart';

class _Response {
  const _Response(this.status, this.bytes, this.headers);
  final int status;
  final Uint8List bytes;
  final HttpHeaders headers;
  Map<String, dynamic> get json =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}

void main() {
  late Directory directory;
  late AppDatabase database;
  late AccountStore accounts;
  late HttpServer server;
  late HttpClient client;
  late CareAccount admin;
  late String cookie;
  late String csrf;
  Future<_Response> call(
    String method,
    String path, {
    Map<String, Object?>? body,
    Uint8List? archive,
    String? safety,
    String? key,
  }) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );
    if (path != '/api/v1/auth/login') {
      request.headers.set('Cookie', cookie);
      request.headers.set('X-CSRF-Token', csrf);
    }
    if (safety != null) request.headers.set('X-Safety-Token', safety);
    if (key != null) request.headers.set('Idempotency-Key', key);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    if (archive != null) {
      request.headers.set(
        'X-Restore-Confirmation',
        'replace-shared-collection',
      );
      request.headers.contentType = ContentType.parse(
        'application/vnd.terramanager.backup+zip',
      );
      request.add(archive);
    }
    final response = await request.close();
    final bytes = BytesBuilder();
    await for (final chunk in response) {
      bytes.add(chunk);
    }
    return _Response(response.statusCode, bytes.takeBytes(), response.headers);
  }

  Future<List<Map<String, dynamic>>> events() async => [
    for (final row
        in await database
            .customSelect(
              'SELECT * FROM shared_audit_events ORDER BY occurred_at, id',
            )
            .get())
      row.data,
  ];
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tm-audit-');
    accounts = await AccountStore.open(
      File('${directory.path}/accounts.sqlite'),
    );
    database = await openServerDatabase(
      File('${directory.path}/collection.sqlite'),
    );
    admin = await accounts.createInitialAdministrator(
      'admin',
      'secure admin password 123',
    );
    server = await SharedServerApi(
      database: database,
      accounts: accounts,
      publicUrl: Uri.parse('http://127.0.0.1'),
    ).serve();
    client = HttpClient();
    final login = await call(
      'POST',
      '/api/v1/auth/login',
      body: {'username': 'admin', 'password': 'secure admin password 123'},
    );
    cookie = login.headers.value('Set-Cookie')!.split(';').first;
    csrf = login.json['csrfToken'] as String;
  });
  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    await database.close();
    accounts.close();
    await directory.delete(recursive: true);
  });

  test(
    'collection actions retain actor and IDs without copying payloads',
    () async {
      const secret = 'PRIVATE NOTES NEVER AUDIT';
      final box = await call(
        'POST',
        '/api/v1/boxes',
        body: {'name': secret, 'notes': secret},
      );
      expect(box.status, 201);
      final boxId = box.json['box']['id'] as int;
      final animal = await call(
        'POST',
        '/api/v1/animals',
        body: {
          'boxId': boxId,
          'commonName': secret,
          'latinName': 'Example species',
          'tempMin': 22,
          'tempMax': 28,
          'humidityMin': 40,
          'humidityMax': 60,
          'notes': secret,
        },
      );
      expect(animal.status, 201, reason: animal.json.toString());
      final animalId = animal.json['animal']['id'] as int;
      final weight = await call(
        'POST',
        '/api/v1/animals/$animalId/weights',
        body: {'weightGrams': 12.5},
      );
      expect(weight.status, 201);
      expect(
        (await call(
          'DELETE',
          '/api/v1/animals/$animalId/weights/${weight.json['weight']['id']}',
        )).status,
        200,
      );
      final shed = await call(
        'POST',
        '/api/v1/animals/$animalId/shedding',
        body: {'notes': secret},
      );
      expect(shed.status, 201);
      final picture = await call(
        'POST',
        '/api/v1/animals/$animalId/pictures',
        body: {
          'fileName': 'secret.png',
          'mimeType': 'image/png',
          'dataBase64': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ioAAAAASUVORK5CYII=',
        },
      );
      expect(picture.status, 201);
      const key = '11111111-1111-4111-8111-111111111111';
      final feed = {
        'animalIds': [animalId],
        'fedAt': '2026-09-26T10:00:00Z',
        'notes': secret,
      };
      expect(
        (await call('POST', '/api/v1/feedings', body: feed, key: key)).status,
        201,
      );
      expect(
        (await call('POST', '/api/v1/feedings', body: feed, key: key)).status,
        201,
      );
      expect(
        (await call(
          'POST',
          '/api/v1/animals/$animalId/archive',
          body: {'reason': 'other'},
        )).status,
        200,
      );
      expect(
        (await call(
          'POST',
          '/api/v1/animals/$animalId/restore',
          body: {'boxId': boxId},
        )).status,
        200,
      );
      final entries = await events();
      expect(
        entries.map((e) => e['action']),
        containsAll([
          'box.create',
          'animal.create',
          'weight.create',
          'weight.delete',
          'shedding.create',
          'media.create',
          'feeding.create',
          'animal.archive',
          'animal.restore',
        ]),
      );
      final feeding = entries
          .where((e) => e['action'] == 'feeding.create')
          .toList();
      expect(
        feeding.map((e) => e['outcome']),
        containsAll(['success', 'replayed']),
      );
      expect(feeding.map((e) => e['record_id']).toSet(), hasLength(1));
      for (final entry in entries) {
        expect(entry['actor_id'], admin.auditId);
        expect(entry['actor_name'], 'admin');
        expect(entry['actor_role'], 'administrator');
        expect(DateTime.parse(entry['occurred_at'] as String).isUtc, true);
        expect(entry['record_id'], isNotNull);
      }
      final encoded = jsonEncode(entries);
      for (final excluded in [
        secret,
        'secret.png',
        cookie,
        csrf,
        'secure admin password 123',
        'dataBase64',
      ]) {
        expect(encoded, isNot(contains(excluded)));
      }
      final before = entries.map((e) => e['id']).toSet();
      final backup = await call('GET', '/api/v1/admin/backups');
      expect(backup.status, 200);
      final restored = await call(
        'POST',
        '/api/v1/admin/backups/restore',
        archive: backup.bytes,
        safety: backup.headers.value('X-Safety-Token'),
      );
      expect(restored.status, 200, reason: restored.json.toString());
      expect((await events()).map((e) => e['id']), containsAll(before));
      expect((await events()).last['action'], 'collection.restore');
      expect(accounts.accountById(admin.id)!.auditId, admin.auditId);
    },
  );

  test(
    'audit failure rolls back collection, restore and cached feeding success',
    () async {
      await database.customStatement(
        "CREATE TRIGGER fail_audit BEFORE INSERT ON shared_audit_events BEGIN SELECT RAISE(ABORT, 'audit unavailable'); END",
      );
      expect(
        (await call(
          'POST',
          '/api/v1/boxes',
          body: {'name': 'Must roll back'},
        )).status,
        greaterThanOrEqualTo(400),
      );
      expect(await database.select(database.boxes).get(), isEmpty);
      await database.customStatement('DROP TRIGGER fail_audit');
      final box = await call(
        'POST',
        '/api/v1/boxes',
        body: {'name': 'Original'},
      );
      final id = box.json['box']['id'];
      final backup = await call('GET', '/api/v1/admin/backups');
      await database.customStatement(
        "UPDATE boxes SET name = 'Changed' WHERE id = ?",
        [id],
      );
      await database.customStatement(
        "CREATE TRIGGER fail_audit BEFORE INSERT ON shared_audit_events BEGIN SELECT RAISE(ABORT, 'audit unavailable'); END",
      );
      expect(
        (await call(
          'POST',
          '/api/v1/admin/backups/restore',
          archive: backup.bytes,
          safety: backup.headers.value('X-Safety-Token'),
        )).status,
        greaterThanOrEqualTo(400),
      );
      expect(
        (await database.select(database.boxes).get()).single.name,
        'Changed',
      );
      await database.customStatement('DROP TRIGGER fail_audit');
      final animal = await call(
        'POST',
        '/api/v1/animals',
        body: {
          'boxId': id,
          'commonName': 'Animal',
          'latinName': 'Example',
          'tempMin': 22,
          'tempMax': 28,
          'humidityMin': 40,
          'humidityMax': 60,
        },
      );
      final animalId = animal.json['animal']['id'];
      await database.customStatement(
        "CREATE TRIGGER fail_audit BEFORE INSERT ON shared_audit_events BEGIN SELECT RAISE(ABORT, 'audit unavailable'); END",
      );
      const key = '22222222-2222-4222-8222-222222222222';
      final body = {
        'animalIds': [animalId],
        'fedAt': '2026-09-26T11:00:00Z',
      };
      expect(
        (await call('POST', '/api/v1/feedings', body: body, key: key)).status,
        greaterThanOrEqualTo(400),
      );
      expect(await database.select(database.feedingEvents).get(), isEmpty);
      await database.customStatement('DROP TRIGGER fail_audit');
      expect(
        (await call('POST', '/api/v1/feedings', body: body, key: key)).status,
        201,
      );
      expect(await database.select(database.feedingEvents).get(), hasLength(1));
    },
  );

  test(
    'account audit is atomic and stable after deactivation and removal',
    () async {
      final added = await call(
        'POST',
        '/api/v1/admin/accounts',
        body: {
          'username': 'keeper',
          'password': 'keeper secret password 123',
          'role': 'caregiver',
        },
      );
      expect(added.status, 201);
      final id = added.json['account']['id'] as int;
      final actorId = accounts.accountById(id)!.auditId;
      expect(
        (await call(
          'PATCH',
          '/api/v1/admin/accounts/$id',
          body: {'active': false},
        )).status,
        200,
      );
      final raw = sqlite.sqlite3.open('${directory.path}/accounts.sqlite');
      try {
        final snapshots = raw.select(
          'SELECT * FROM shared_audit_events WHERE record_id = ?',
          [actorId],
        );
        expect(snapshots, hasLength(2));
        expect(snapshots.every((e) => e['actor_id'] == admin.auditId), true);
        expect(
          jsonEncode(snapshots),
          isNot(contains('keeper secret password 123')),
        );
        // The future removal workflow must not cascade into audit metadata.
        raw.execute('DELETE FROM accounts WHERE id = ?', [id]);
        expect(
          raw.select('SELECT * FROM shared_audit_events WHERE record_id = ?', [
            actorId,
          ]),
          hasLength(2),
        );
        raw.execute(
          "CREATE TRIGGER fail_account_audit BEFORE INSERT ON shared_audit_events BEGIN SELECT RAISE(ABORT, 'audit unavailable'); END",
        );
        expect(
          (await call(
            'POST',
            '/api/v1/admin/accounts',
            body: {
              'username': 'failed',
              'password': 'new secret password 123',
              'role': 'caregiver',
            },
          )).status,
          greaterThanOrEqualTo(400),
        );
        expect(
          accounts.listAccounts().map((e) => e.username),
          isNot(contains('failed')),
        );
        raw.execute('DROP TRIGGER fail_account_audit');
      } finally {
        raw.close();
      }
    },
  );

  test('retention removes only expired audit metadata and keeps collection intact', () async {
    final box = await call('POST', '/api/v1/boxes', body: {'name': 'Retained'});
    await database.customStatement(
      "UPDATE shared_audit_events SET occurred_at = '2000-01-01T00:00:00.000Z'",
    );
    await CollectionAuditLog(database).record(
      AuditEvent(
        actor: admin.auditActor,
        action: 'box.update',
        recordType: 'box',
        recordId: '${box.json['box']['id']}',
        outcome: 'success',
        statusCode: 200,
      ),
    );
    expect(await events(), hasLength(1));
    expect(
      (await database.select(database.boxes).get()).single.name,
      'Retained',
    );
  });
  test('caregiver attribution survives removal and concurrent feeding retry is unique', () async {
    final added = await call(
      'POST',
      '/api/v1/admin/accounts',
      body: {
        'username': 'keeper',
        'password': 'keeper secret password 123',
        'role': 'caregiver',
      },
    );
    final accountId = added.json['account']['id'] as int;
    final identity = accounts.accountById(accountId)!.auditId;
    final login = await call(
      'POST',
      '/api/v1/auth/login',
      body: {'username': 'keeper', 'password': 'keeper secret password 123'},
    );
    cookie = login.headers.value('Set-Cookie')!.split(';').first;
    csrf = login.json['csrfToken'] as String;
    final box = await call(
      'POST',
      '/api/v1/boxes',
      body: {'name': 'Caregiver Box'},
    );
    final animal = await call(
      'POST',
      '/api/v1/animals',
      body: {
        'boxId': box.json['box']['id'],
        'commonName': 'Animal',
        'latinName': 'Example',
        'tempMin': 22,
        'tempMax': 28,
        'humidityMin': 40,
        'humidityMax': 60,
      },
    );
    final payload = {
      'animalIds': [animal.json['animal']['id']],
      'fedAt': '2026-09-26T12:00:00Z',
    };
    const key = '33333333-3333-4333-8333-333333333333';
    final replies = await Future.wait([
      call('POST', '/api/v1/feedings', body: payload, key: key),
      call('POST', '/api/v1/feedings', body: payload, key: key),
    ]);
    expect(replies.map((e) => e.status), everyElement(201));
    expect(await database.select(database.feedingEvents).get(), hasLength(1));
    final before = await events();
    expect(
      before.every(
        (e) => e['actor_id'] == identity && e['actor_role'] == 'caregiver',
      ),
      true,
    );
    await accounts.updateAccount(accountId, active: false, actor: admin);
    final raw = sqlite.sqlite3.open('${directory.path}/accounts.sqlite');
    raw.execute('DELETE FROM accounts WHERE id = ?', [accountId]);
    raw.close();
    expect(
      (await events()).every(
        (e) => e['actor_id'] == identity && e['actor_name'] == 'keeper',
      ),
      true,
    );
  });

  test(
    'existing account audit identity is migrated once and survives reopen',
    () async {
      final file = File('${directory.path}/legacy-accounts.sqlite');
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute(
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, role TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1)',
      );
      raw.execute(
        "INSERT INTO accounts VALUES (1, 'legacy', 'existing password hash', 'administrator', 1)",
      );
      raw.close();
      var migrated = await AccountStore.open(file);
      final identity = migrated.accountById(1)!.auditId;
      expect(identity, isNotEmpty);
      expect(migrated.accountById(1)!.username, 'legacy');
      migrated.close();
      migrated = await AccountStore.open(file);
      expect(migrated.accountById(1)!.auditId, identity);
      migrated.close();
      final reopened = sqlite.sqlite3.open(file.path);
      expect(
        reopened
            .select('SELECT password_hash FROM accounts')
            .single['password_hash'],
        'existing password hash',
      );
      reopened.close();
    },
  );
}
