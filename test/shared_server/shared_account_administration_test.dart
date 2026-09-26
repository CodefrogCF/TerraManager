import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:terramanager/shared_server/account_store.dart';
import 'package:terramanager/shared_server/server_database.dart';
import 'package:terramanager/shared_server/shared_server_api.dart';

class _Response {
  final int status;
  final Map<String, dynamic> body;
  final String? cookie;

  _Response(this.status, this.body, this.cookie);
}

Future<_Response> _call(
  HttpClient client,
  HttpServer server,
  String method,
  String path, {
  Map<String, Object?>? body,
  String? cookie,
  String? csrf,
  String? origin,
}) async {
  final request = await client.openUrl(
    method,
    Uri.parse('http://127.0.0.1:${server.port}$path'),
  );
  if (cookie != null) request.headers.set(HttpHeaders.cookieHeader, cookie);
  if (csrf != null) request.headers.set('X-CSRF-Token', csrf);
  if (origin != null) request.headers.set('Origin', origin);
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close();
  final text = await utf8.decoder.bind(response).join();
  return _Response(
    response.statusCode,
    jsonDecode(text) as Map<String, dynamic>,
    response.headers.value(HttpHeaders.setCookieHeader)?.split(';').first,
  );
}

void main() {
  test('account administration enforces roles, confirmations and last administrator protection', () async {
    final directory = await Directory.systemTemp.createTemp('tm-admin-');
    final accounts = await AccountStore.open(
      File('${directory.path}/accounts.sqlite'),
    );
    final database = await openServerDatabase(
      File('${directory.path}/collection.sqlite'),
    );
    final admin = await accounts.createInitialAdministrator(
      'admin',
      'admin password 1234',
    );
    final caregiver = await accounts.createAccount(
      'caregiver',
      'caregiver password 1234',
      CareRole.caregiver,
    );
    final auditId = caregiver.auditId;
    final client = HttpClient();
    final server = await SharedServerApi(
      database: database,
      accounts: accounts,
      publicUrl: Uri.parse('http://127.0.0.1'),
    ).serve();
    try {
      Future<_Response> login(String name, String password) => _call(
        client,
        server,
        'POST',
        '/api/v1/auth/login',
        body: {'username': name, 'password': password},
        origin: 'http://127.0.0.1',
      );
      final adminLogin = await login('admin', 'admin password 1234');
      final caregiverLogin = await login(
        'caregiver',
        'caregiver password 1234',
      );
      Future<_Response> mutate(
        String method,
        int id,
        Map<String, Object?> body, {
        _Response? actor,
      }) => _call(
        client,
        server,
        method,
        '/api/v1/admin/accounts/$id',
        body: {
          ...body,
          'expectedAuditId': accounts.accountById(id)?.auditId ?? 'missing',
        },
        cookie: (actor ?? adminLogin).cookie,
        csrf: (actor ?? adminLogin).body['csrfToken'] as String,
        origin: 'http://127.0.0.1',
      );
      expect(
        (await _call(
          client,
          server,
          'GET',
          '/api/v1/admin/accounts',
          cookie: caregiverLogin.cookie,
        )).status,
        403,
      );
      expect(
        (await mutate('PATCH', admin.id, {
          'username': 'taken',
        }, actor: caregiverLogin)).status,
        403,
      );
      expect(
        (await mutate('DELETE', admin.id, {
          'confirmation': 'remove-account',
        }, actor: caregiverLogin)).status,
        403,
      );
      expect(
        (await _call(
          client,
          server,
          'PATCH',
          '/api/v1/admin/accounts/${caregiver.id}',
          body: {'active': false},
          cookie: adminLogin.cookie,
          origin: 'http://127.0.0.1',
        )).status,
        403,
      );
      final rename = await mutate('PATCH', caregiver.id, {
        'username': 'renamed',
      });
      expect(rename.status, 200);
      expect(rename.body['sessionRevoked'], false);
      expect(accounts.accountById(caregiver.id)!.auditId, auditId);
      expect(
        (await _call(
          client,
          server,
          'GET',
          '/api/v1/auth/session',
          cookie: caregiverLogin.cookie,
        )).status,
        401,
      );
      expect((await login('caregiver', 'caregiver password 1234')).status, 401);
      expect((await login('renamed', 'caregiver password 1234')).status, 200);
      expect(
        (await mutate('PATCH', caregiver.id, {'username': 'ADMIN'})).status,
        409,
      );
      expect(accounts.accountById(caregiver.id)!.username, 'renamed');
      expect(
        (await mutate('PATCH', caregiver.id, {'active': false})).status,
        200,
      );
      expect((await login('renamed', 'caregiver password 1234')).status, 401);
      expect(
        (await mutate('PATCH', caregiver.id, {
          'active': true,
          'password': 'changed password 1234',
        })).status,
        200,
      );
      expect((await login('renamed', 'caregiver password 1234')).status, 401);
      expect((await login('renamed', 'changed password 1234')).status, 200);
      for (final fields in <Map<String, Object?>>[
        {'active': false},
        {'role': 'caregiver'},
      ]) {
        expect((await mutate('PATCH', admin.id, fields)).status, 409);
      }
      expect(
        (await mutate('DELETE', admin.id, {
          'confirmation': 'remove-account',
        })).status,
        409,
      );
      expect(
        (await mutate('DELETE', caregiver.id, {
          'confirmation': 'wrong',
        })).status,
        400,
      );
      expect(accounts.accountById(caregiver.id), isNotNull);
      final oldSession = accounts.createSession(
        accounts.accountById(caregiver.id)!,
      );
      expect(
        (await mutate('DELETE', caregiver.id, {
          'confirmation': 'remove-account',
        })).status,
        200,
      );
      expect(accounts.accountById(caregiver.id), isNull);
      expect(accounts.findSession(oldSession.token), isNull);
      final reused = await accounts.createAccount(
        'renamed',
        'another password 1234',
        CareRole.caregiver,
      );
      expect(reused.auditId, isNot(auditId));
      expect(
        () => accounts.removeAccount(
          reused.id,
          actor: admin,
          expectedAuditId: auditId,
        ),
        throwsStateError,
      );
      expect(accounts.accountById(reused.id), isNotNull);
      final other = await accounts.createAccount(
        'otheradmin',
        'another admin password',
        CareRole.administrator,
      );
      final selfChange = await mutate('PATCH', admin.id, {
        'username': 'adminrenamed',
      });
      expect(selfChange.status, 200);
      expect(selfChange.body['sessionRevoked'], true);
      expect(
        (await _call(
          client,
          server,
          'GET',
          '/api/v1/admin/accounts',
          cookie: adminLogin.cookie,
        )).status,
        401,
      );
      expect(other.active, true);
    } finally {
      client.close(force: true);
      await server.close(force: true);
      accounts.close();
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test('failed deletion audit rolls back credentials and sessions; removed actor identity remains', () async {
    final directory = await Directory.systemTemp.createTemp('tm-admin-atomic-');
    final file = File('${directory.path}/accounts.sqlite');
    final accounts = await AccountStore.open(file);
    final inspector = sqlite3.open(file.path);
    try {
      final admin = await accounts.createInitialAdministrator(
        'admin',
        'admin password 1234',
      );
      final user = await accounts.createAccount(
        'user',
        'user password 1234',
        CareRole.caregiver,
        actor: admin,
      );
      final session = accounts.createSession(user);
      inspector.execute(
        "CREATE TRIGGER fail_delete_audit BEFORE INSERT ON shared_audit_events WHEN NEW.action = 'account.delete' BEGIN SELECT RAISE(ABORT, 'audit unavailable'); END",
      );
      expect(
        () => accounts.removeAccount(user.id, actor: admin),
        throwsA(isA<SqliteException>()),
      );
      expect(accounts.accountById(user.id), isNotNull);
      expect(accounts.findSession(session.token), isNotNull);
      expect(
        await accounts.authenticate('user', 'user password 1234'),
        isNotNull,
      );
      inspector.execute('DROP TRIGGER fail_delete_audit');
      accounts.removeAccount(user.id, actor: admin);
      final row = inspector
          .select(
            "SELECT * FROM shared_audit_events WHERE action = 'account.delete'",
          )
          .single;
      expect(row['record_id'], user.auditId);
      expect(row['actor_id'], admin.auditId);
      expect(accounts.findSession(session.token), isNull);
      expect(await accounts.authenticate('user', 'user password 1234'), isNull);
    } finally {
      inspector.close();
      accounts.close();
      await directory.delete(recursive: true);
    }
  });
  test('concurrent hashed administrator demotions leave one active administrator and reject stale actors', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tm-admin-concurrent-',
    );
    final accounts = await AccountStore.open(
      File('${directory.path}/accounts.sqlite'),
    );
    try {
      final first = await accounts.createInitialAdministrator(
        'first',
        'first password 1234',
      );
      final second = await accounts.createAccount(
        'second',
        'second password 1234',
        CareRole.administrator,
      );
      Future<bool> demote(CareAccount target) async {
        try {
          await accounts.updateAccount(
            target.id,
            role: CareRole.caregiver,
            password: 'changed password 1234',
            actor: target,
          );
          return true;
        } on StateError {
          return false;
        }
      }

      final results = await Future.wait([demote(first), demote(second)]);
      expect(results.where((value) => value).length, 1);
      final remaining = accounts
          .listAccounts()
          .where((a) => a.active && a.role == CareRole.administrator)
          .single;
      final stale = remaining.id == first.id ? second : first;
      await expectLater(
        accounts.createAccount(
          'unauthorized',
          'another password 1234',
          CareRole.caregiver,
          actor: stale,
        ),
        throwsStateError,
      );
      expect(accounts.listAccounts().length, 2);
    } finally {
      accounts.close();
      await directory.delete(recursive: true);
    }
  });
}
