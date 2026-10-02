import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/audit/domain/audit_event.dart';
import 'package:terramanager/shared_server/audit/infrastructure/audit_schema.dart';
import 'package:terramanager/shared_server/audit/infrastructure/collection_audit_log.dart';
import 'package:terramanager/shared_server/app/shared_server_api.dart';

import '../helpers/test_database_helper.dart';

void main() {
  TestDatabaseHelper? helper;
  late AppDatabase database;
  late AccountStore accounts;
  sqlite.Database? accountDatabase;
  HttpServer? server;
  HttpClient? client;
  late String adminCookie;
  late String caregiverCookie;
  late String csrf;
  final now = DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch,
    isUtc: true,
  ).subtract(const Duration(hours: 1));

  Future<(int, Map<String, dynamic>, HttpHeaders)> call(
    String path, {
    String? cookie,
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final request = await client!.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server!.port}$path'),
    );
    if (cookie != null) request.headers.set('Cookie', cookie);
    if (body != null) {
      request.headers.set('X-CSRF-Token', csrf);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    return (
      response.statusCode,
      jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>,
      response.headers,
    );
  }

  Future<AuditEvent> seed(
    String source,
    DateTime time, {
    String actor = 'caregiver',
    String action = 'animal.update',
    String? recordId = '42',
  }) async {
    final event = AuditEvent(
      actor: AuditActor('stable-$actor', actor, 'caregiver'),
      action: action,
      recordType: source == 'account' ? 'account' : 'animal',
      recordId: recordId,
      outcome: 'success',
      statusCode: 200,
      occurredAt: time,
    );
    if (source == 'account') {
      accountDatabase!.execute(auditInsertSql, event.sqlValues);
    } else {
      await CollectionAuditLog(database).record(event);
    }
    return event;
  }

  setUp(() async {
    final created = await TestDatabaseHelper.create(prefix: 'tm-audit-viewer-');
    helper = created;
    accounts = created.accounts;
    database = created.database;
    client = HttpClient();
    await accounts.createInitialAdministrator(
      'admin',
      'secure admin password 123',
    );
    await accounts.createAccount(
      'caregiver',
      'secure caregiver password 123',
      CareRole.caregiver,
    );
    server = await SharedServerApi(
      database: database,
      accounts: accounts,
      publicUrl: Uri.parse('http://127.0.0.1'),
    ).serve();
    csrf = '';
    final admin = await call(
      '/api/v1/auth/login',
      method: 'POST',
      body: {'username': 'admin', 'password': 'secure admin password 123'},
    );
    adminCookie = admin.$3.value('Set-Cookie')!.split(';').first;
    csrf = admin.$2['csrfToken'] as String;
    final caregiver = await call(
      '/api/v1/auth/login',
      method: 'POST',
      body: {
        'username': 'caregiver',
        'password': 'secure caregiver password 123',
      },
    );
    caregiverCookie = caregiver.$3.value('Set-Cookie')!.split(';').first;
    accountDatabase = sqlite.sqlite3.open(created.accountsDbFile.path);
    accountDatabase!.execute('DELETE FROM shared_audit_events');
  });

  tearDown(() async {
    await server?.close(force: true);
    server = null;
    client?.close(force: true);
    client = null;
    accountDatabase?.close();
    accountDatabase = null;
    await helper?.cleanup();
    helper = null;
  });

  test('administrator authorization precedes filters and empty history is explicit', () async {
    expect((await call('/api/v1/admin/audit')).$1, 401);
    expect(
      (await call('/api/v1/admin/audit?limit=bad', cookie: caregiverCookie)).$1,
      403,
    );
    final empty = await call('/api/v1/admin/audit', cookie: adminCookie);
    expect(empty.$1, 200);
    expect(empty.$2, {'events': [], 'nextCursor': null});
    expect(empty.$3.value('Cache-Control'), 'no-store');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'bounded pages merge both streams with stable timestamp/source/id ties',
    () async {
      final expected = <(AuditEvent, String)>[];
      for (var i = 0; i < 11; i++) {
        final source = i.isEven ? 'collection' : 'account';
        // Include equal times and mixed fractional precision within one millisecond.
        final time = now.add(Duration(microseconds: i < 6 ? 0 : i));
        expected.add((await seed(source, time), source));
      }
      expected.sort((a, b) {
        final time = b.$1.occurredAt.compareTo(a.$1.occurredAt);
        if (time != 0) return time;
        final source = b.$2.compareTo(a.$2);
        return source != 0 ? source : b.$1.id.compareTo(a.$1.id);
      });
      final seen = <String>[];
      String? cursor;
      do {
        final path = Uri(
          path: '/api/v1/admin/audit',
          queryParameters: {'limit': '3', 'cursor': ?cursor},
        ).toString();
        final response = await call(path, cookie: adminCookie);
        expect(response.$1, 200, reason: response.$2.toString());
        final events = response.$2['events'] as List;
        expect(events.length, lessThanOrEqualTo(3));
        seen.addAll(events.map((e) => e['id'] as String));
        cursor = response.$2['nextCursor'] as String?;
        if (seen.length == 3) {
          await seed('collection', now.add(const Duration(minutes: 1)));
        }
      } while (cursor != null);
      expect(seen, expected.map((e) => e.$1.id).toList());
      expect(seen.toSet(), hasLength(11));
    },
  );

  test(
    'date, actor and action filters combine and treat input literally',
    () async {
      final wanted = await seed('account', now, actor: 'admin.old');
      await seed('collection', now, actor: 'other');
      await seed(
        'collection',
        now,
        actor: 'admin.old',
        action: 'animal.create',
      );
      await seed(
        'collection',
        now.add(const Duration(days: 1)),
        actor: 'admin.old',
      );
      await seed(
        'account',
        now.subtract(const Duration(days: 400)),
        actor: 'admin.old',
      );
      final response = await call(
        Uri(
          path: '/api/v1/admin/audit',
          queryParameters: {
            'from': now.toIso8601String(),
            'until': now.add(const Duration(days: 1)).toIso8601String(),
            'actor': 'ADMIN',
            'action': 'update',
          },
        ).toString(),
        cookie: adminCookie,
      );
      expect(response.$1, 200);
      expect((response.$2['events'] as List).single['id'], wanted.id);
      for (final literal in ["' OR 1=1 --", '%', 'SOURCE']) {
        final result = await call(
          Uri(
            path: '/api/v1/admin/audit',
            queryParameters: {'actor': literal},
          ).toString(),
          cookie: adminCookie,
        );
        expect(result.$1, 200);
        expect(result.$2['events'], isEmpty);
      }
    },
  );

  test(
    'invalid filters and cursors are rejected without server details',
    () async {
      for (final query in [
        'limit=0',
        'limit=101',
        'limit=no',
        'limit=2&limit=3',
        'extra=x',
        'action=password',
        'actor=',
        'from=tomorrow',
        'cursor=garbage',
        'from=2026-09-27T00:00:00.000Z&until=2026-09-26T00:00:00.000Z',
        'cursor=${base64Url.encode(utf8.encode(jsonEncode([1, 2, 3])))}',
      ]) {
        final response = await call(
          '/api/v1/admin/audit?$query',
          cookie: adminCookie,
        );
        expect(response.$1, 400, reason: query);
        expect(response.$2['events'], isNull);
      }
    },
  );

  test(
    'API exposes metadata only and retains account attribution after deletion',
    () async {
      const private = 'PRIVATE NOTES NEVER RETURN';
      final mutation = await call(
        '/api/v1/boxes',
        cookie: adminCookie,
        method: 'POST',
        body: {'name': private, 'notes': private},
      );
      expect(mutation.$1, 201);
      final user = accounts.listAccounts().firstWhere(
        (a) => a.username == 'caregiver',
      );
      accounts.removeAccount(
        user.id,
        actor: accounts.listAccounts().firstWhere((a) => a.username == 'admin'),
      );
      final result = await call('/api/v1/admin/audit', cookie: adminCookie);
      expect(result.$1, 200);
      final events = result.$2['events'] as List;
      expect(
        events.map((e) => e['action']),
        containsAll(['box.create', 'account.delete']),
      );
      expect(
        events.firstWhere((e) => e['action'] == 'account.delete')['recordId'],
        user.auditId,
      );
      for (final event in events) {
        expect((event as Map).keys.toSet(), {
          'id',
          'source',
          'occurredAt',
          'actorId',
          'actorName',
          'actorRole',
          'action',
          'recordType',
          'recordId',
          'outcome',
          'statusCode',
        });
      }
      final encoded = jsonEncode(result.$2);
      for (final secret in [
        private,
        adminCookie,
        csrf,
        'secure admin password 123',
        'password_hash',
      ]) {
        expect(encoded, isNot(contains(secret)));
      }
    },
  );
}
