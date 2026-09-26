import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/accounts/presentation/pages/shared_accounts_section.dart';

void main() {
  testWidgets('edit account fields and explicitly confirm deletion', (
    tester,
  ) async {
    var user = <String, dynamic>{
      'id': 2,
      'auditId': 'user-audit-id',
      'username': 'user',
      'role': 'caregiver',
      'active': true,
    };
    Map<String, dynamic>? saved;
    var deletes = 0;
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({
              'user': {'username': 'admin', 'role': 'administrator'},
              'csrfToken': 'csrf',
            }),
            200,
          );
        }
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'accounts': deletes == 0 ? [user] : [],
            }),
            200,
          );
        }
        expect(request.headers['X-CSRF-Token'], 'csrf');
        if (request.method == 'PATCH') {
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          user = {...user, ...saved!};
          return http.Response(
            jsonEncode({'account': user, 'sessionRevoked': false}),
            200,
          );
        }
        if (request.method == 'DELETE') {
          expect(jsonDecode(request.body), {
            'confirmation': 'remove-account',
            'expectedAuditId': 'user-audit-id',
          });
          deletes++;
          return http.Response('{"removed":true,"sessionRevoked":false}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    await api.login('admin', 'password');
    await tester.pumpWidget(MaterialApp(home: SharedAccountsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-account-2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('signs this user out'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('account-username')),
      'Renamed',
    );
    await tester.enterText(
      find.byKey(const Key('account-password')),
      'new password 1234',
    );
    await tester.tap(find.byKey(const Key('account-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrator').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-active')));
    await tester.tap(find.byKey(const Key('save-account')));
    await tester.pumpAndSettle();
    expect(saved, {
      'expectedAuditId': 'user-audit-id',
      'username': 'renamed',
      'role': 'administrator',
      'active': false,
      'password': 'new password 1234',
    });
    expect(find.text('renamed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove-account-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.byKey(const Key('remove-account-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-remove-account')));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.byKey(const Key('shared-account-2')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caregiver cannot load or use account administration', (
    tester,
  ) async {
    var requests = 0;
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        requests++;
        return http.Response(
          jsonEncode({
            'user': {'username': 'user', 'role': 'caregiver'},
            'csrfToken': 'csrf',
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await api.login('user', 'password');
    await tester.pumpWidget(MaterialApp(home: SharedAccountsPage(api: api)));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Administrator access required.'), findsOneWidget);
    expect(find.byKey(const Key('add-account')), findsNothing);
  });

  testWidgets(
    'self edit clears the client session and returns to root; conflicts keep the page',
    (tester) async {
      var conflict = true;
      final account = {
        'id': 1,
        'auditId': 'admin-audit-id',
        'username': 'admin',
        'role': 'administrator',
        'active': true,
      };
      final api = SharedApiClient(
        Uri.parse('https://192.168.1.117'),
        MockClient((request) async {
          if (request.url.path == '/api/v1/auth/login') {
            return http.Response(
              jsonEncode({'user': account, 'csrfToken': 'csrf'}),
              200,
            );
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'accounts': [account],
              }),
              200,
            );
          }
          if (conflict) {
            return http.Response(
              '{"error":{"code":"conflict","message":"The last active administrator cannot be removed."}}',
              409,
            );
          }
          return http.Response(
            jsonEncode({
              'account': {...account, 'username': 'newadmin'},
              'sessionRevoked': true,
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await api.login('admin', 'password');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SharedAccountsPage(api: api),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      Future<void> edit() async {
        await tester.tap(find.byKey(const Key('edit-account-1')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('account-username')),
          'newadmin',
        );
        await tester.tap(find.byKey(const Key('save-account')));
        await tester.pumpAndSettle();
      }

      await edit();
      expect(find.byKey(const Key('account-change-error')), findsOneWidget);
      expect(api.session, isNotNull);
      conflict = false;
      await edit();
      expect(api.session, isNull);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'German administration creates an account with localized feedback',
    (tester) async {
      Map<String, dynamic>? created;
      final api = SharedApiClient(
        Uri.parse('https://192.168.1.117'),
        MockClient((request) async {
          if (request.url.path == '/api/v1/auth/login') {
            return http.Response(
              '{"user":{"username":"admin","role":"administrator"},"csrfToken":"csrf"}',
              200,
            );
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'accounts': created == null
                    ? []
                    : [
                        {...created!, 'id': 2, 'active': true},
                      ],
              }),
              200,
            );
          }
          created = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'account': {...created!, 'id': 2, 'active': true},
            }),
            201,
          );
        }),
      );
      addTearDown(api.close);
      await api.login('admin', 'password');
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SharedAccountsPage(api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Konten verwalten'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-account')));
      await tester.pumpAndSettle();
      expect(created, isNull);
      expect(find.textContaining('Benutzername: 3–64'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('account-username')),
        'Betreuer',
      );
      await tester.enterText(
        find.byKey(const Key('account-password')),
        'caregiver password 123',
      );
      await tester.tap(find.byKey(const Key('save-account')));
      await tester.pumpAndSettle();
      expect(created, {
        'username': 'betreuer',
        'password': 'caregiver password 123',
        'role': 'caregiver',
      });
      expect(find.text('Betreuung · Aktiv'), findsOneWidget);
      expect(find.text('Konto gespeichert.'), findsOneWidget);
    },
  );
}
