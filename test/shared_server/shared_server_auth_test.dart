import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  test(
    'local accounts gate collection and media, roles, CSRF and sessions',
    () async {
      final directory = await Directory.systemTemp.createTemp('tm-auth-test-');
      final accounts = await AccountStore.open(
        File('${directory.path}${Platform.pathSeparator}accounts.sqlite'),
      );
      final database = await openServerDatabase(
        File('${directory.path}${Platform.pathSeparator}collection.sqlite'),
      );
      final client = HttpClient();
      HttpServer? server;
      try {
        expect(accounts.hasAccounts, false);
        final admin = await accounts.createInitialAdministrator(
          'Admin',
          'a secure admin password 123',
        );
        expect(admin.role, CareRole.administrator);
        expect(accounts.hasAccounts, true);
        await expectLater(
          accounts.createInitialAdministrator('other', 'another password 123'),
          throwsStateError,
        );
        final authFile = File(
          '${directory.path}${Platform.pathSeparator}accounts.sqlite',
        );
        final disk = await authFile.readAsBytes();
        expect(
          utf8.decode(disk, allowMalformed: true),
          isNot(contains('a secure admin password 123')),
        );

        server = await SharedServerApi(
          database: database,
          accounts: accounts,
          publicUrl: Uri.parse('http://127.0.0.1'),
        ).serve();

        final health = await _call(client, server, 'GET', '/api/v1/health');
        expect(health.status, 200);
        expect(health.body, {'status': 'ok'});
        expect(health.cookie, isNull);

        expect(
          (await _call(client, server, 'GET', '/api/v1/boxes')).status,
          401,
        );
        expect(
          (await _call(client, server, 'GET', '/api/v1/media/1')).status,
          401,
        );
        final wrong = await _call(
          client,
          server,
          'POST',
          '/api/v1/auth/login',
          body: {'username': 'admin', 'password': 'wrong'},
        );
        expect(wrong.status, 401);
        final login = await _call(
          client,
          server,
          'POST',
          '/api/v1/auth/login',
          body: {
            'username': 'admin',
            'password': 'a secure admin password 123',
          },
        );
        expect(login.status, 200, reason: login.body.toString());
        expect(login.cookie, startsWith('__Host-TerraManagerSession='));
        final adminCookie = login.cookie!;
        final adminCsrf = login.body['csrfToken'] as String;
        final token = adminCookie.split('=').last;
        expect(accounts.findSession(token), isNotNull);
        expect(
          accounts.findSession(
            token,
            now: DateTime.now().toUtc().add(
              AccountStore.sessionLifetime + const Duration(seconds: 1),
            ),
          ),
          isNull,
        );

        final expired = accounts.createSession(
          admin,
          now: DateTime.now().toUtc().subtract(
            AccountStore.sessionLifetime + const Duration(minutes: 1),
          ),
        );
        expect(
          (await _call(
            client,
            server,
            'GET',
            '/api/v1/boxes',
            cookie: '__Host-TerraManagerSession=${expired.token}',
          )).status,
          401,
        );

        final missingCsrf = await _call(
          client,
          server,
          'POST',
          '/api/v1/boxes',
          cookie: adminCookie,
          body: {'name': 'Nope'},
        );
        expect(missingCsrf.status, 403);
        expect((missingCsrf.body['error'] as Map)['code'], 'csrf_failed');
        final foreign = await _call(
          client,
          server,
          'POST',
          '/api/v1/boxes',
          cookie: adminCookie,
          csrf: adminCsrf,
          origin: 'https://other.example',
          body: {'name': 'Nope'},
        );
        expect(foreign.status, 403);

        final createUser = await _call(
          client,
          server,
          'POST',
          '/api/v1/admin/accounts',
          cookie: adminCookie,
          csrf: adminCsrf,
          body: {
            'username': 'keeper',
            'password': 'caregiver password 123',
            'role': 'caregiver',
          },
        );
        expect(createUser.status, 201, reason: createUser.body.toString());
        expect(
          createUser.body.toString(),
          isNot(contains('caregiver password 123')),
        );
        final caregiverId = (createUser.body['account'] as Map)['id'] as int;
        final keeper = await _call(
          client,
          server,
          'POST',
          '/api/v1/auth/login',
          body: {'username': 'keeper', 'password': 'caregiver password 123'},
        );
        expect(keeper.status, 200);
        final keeperCookie = keeper.cookie!;
        final keeperCsrf = keeper.body['csrfToken'] as String;

        final box = await _call(
          client,
          server,
          'POST',
          '/api/v1/boxes',
          cookie: keeperCookie,
          csrf: keeperCsrf,
          body: {'name': 'Shared Box'},
        );
        expect(box.status, 201, reason: box.body.toString());
        final boxId = (box.body['box'] as Map)['id'];
        expect(
          (await _call(
            client,
            server,
            'GET',
            '/api/v1/boxes/$boxId',
            cookie: adminCookie,
          )).status,
          200,
        );
        expect(
          (await _call(
            client,
            server,
            'GET',
            '/api/v1/admin/accounts',
            cookie: keeperCookie,
          )).status,
          403,
        );
        expect(
          (await _call(
            client,
            server,
            'POST',
            '/api/v1/admin/accounts',
            cookie: keeperCookie,
            csrf: keeperCsrf,
            body: {
              'username': 'evil',
              'password': 'another long password',
              'role': 'administrator',
            },
          )).status,
          403,
        );
        expect(
          (await _call(
            client,
            server,
            'POST',
            '/api/v1/admin/restore',
            cookie: keeperCookie,
            csrf: keeperCsrf,
            body: {},
          )).status,
          403,
        );
        expect(
          (await _call(
            client,
            server,
            'PATCH',
            '/api/v1/admin/accounts/${admin.id}',
            cookie: adminCookie,
            csrf: adminCsrf,
            body: {'role': 'caregiver'},
          )).status,
          409,
        );

        final logout = await _call(
          client,
          server,
          'POST',
          '/api/v1/auth/logout',
          cookie: keeperCookie,
          csrf: keeperCsrf,
        );
        expect(logout.status, 200);
        expect(
          (await _call(
            client,
            server,
            'GET',
            '/api/v1/boxes',
            cookie: keeperCookie,
          )).status,
          401,
        );
        final renewed = await _call(
          client,
          server,
          'POST',
          '/api/v1/auth/login',
          body: {'username': 'keeper', 'password': 'caregiver password 123'},
        );
        expect(renewed.status, 200);
        final changed = await _call(
          client,
          server,
          'PATCH',
          '/api/v1/admin/accounts/$caregiverId',
          cookie: adminCookie,
          csrf: adminCsrf,
          body: {'active': false},
        );
        expect(changed.status, 200);
        expect(
          (await _call(
            client,
            server,
            'GET',
            '/api/v1/boxes',
            cookie: renewed.cookie,
          )).status,
          401,
        );
        final inactive = await _call(
          client,
          server,
          'POST',
          '/api/v1/auth/login',
          body: {'username': 'keeper', 'password': 'caregiver password 123'},
        );
        expect(inactive.status, 401);

        final secondAdmin = await accounts.createAccount(
          'secondadmin',
          'another admin password 123',
          CareRole.administrator,
        );
        final results = await Future.wait([
          accounts
              .updateAccount(
                admin.id,
                active: false,
                password: 'first replacement password 123',
              )
              .then((_) => true)
              .catchError((_) => false),
          accounts
              .updateAccount(
                secondAdmin.id,
                active: false,
                password: 'second replacement password 123',
              )
              .then((_) => true)
              .catchError((_) => false),
        ]);
        expect(results.where((result) => result), hasLength(1));
        expect(
          accounts.listAccounts().where(
            (account) =>
                account.active && account.role == CareRole.administrator,
          ),
          hasLength(1),
        );
      } finally {
        client.close(force: true);
        await server?.close(force: true);
        await database.close();
        accounts.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
