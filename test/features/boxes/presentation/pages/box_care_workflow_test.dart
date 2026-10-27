import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/standalone_box_care_history.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_care_history_page.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_server/boxes/application/box_care_operations.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

void main() {
  for (final mode in ['standalone', 'shared-admin', 'shared-caregiver']) {
    testWidgets('$mode creates edits and confirms permitted care deletion', (
      tester,
    ) async {
      final database = AppDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);
      final box = await BoxRepository(database).createBoxWithGeneratedQrId();
      final care = BoxCareRepository(database);
      final l10n = lookupAppLocalizations(const Locale('en'));
      SharedApiClient? api;
      if (mode != 'standalone') {
        final operations = BoxCareOperations(database);
        api = SharedApiClient(
          Uri.parse('https://test.local'),
          MockClient((request) async {
            final path = request.url.path;
            if (path.endsWith('/login')) {
              return http.Response(
                jsonEncode({
                  'user': {
                    'username': 'user',
                    'role': mode == 'shared-admin'
                        ? 'administrator'
                        : 'caregiver',
                  },
                  'csrfToken': 'token',
                }),
                200,
              );
            }
            if (path == '/api/v1/care-event-types') {
              return http.Response(jsonEncode({'careEventTypes': []}), 200);
            }
            if (path == '/api/v1/boxes/$box') {
              return http.Response(
                jsonEncode({
                  'box': {'id': box, 'status': 'active'},
                }),
                200,
              );
            }
            final parts = path.split('/');
            final input = request.body.isEmpty
                ? ApiInput({})
                : ApiInput.decode(request.body);
            final ApiReply reply;
            if (request.method == 'GET') {
              reply = await operations.list(box);
            } else if (request.method == 'POST') {
              reply = await operations.create(box, input);
            } else if (request.method == 'PUT') {
              reply = await operations.update(
                box,
                int.parse(parts.last),
                input,
              );
            } else {
              reply = await operations.delete(
                box,
                int.parse(parts.last),
                input,
              );
            }
            return http.Response(jsonEncode(reply.body), reply.status);
          }),
        );
        addTearDown(api.close);
        await api.login('user', 'password');
      }
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  if (api == null) {
                    openStandaloneBoxCareHistory(
                      context,
                      database: database,
                      boxId: box,
                      label: 'Test Box',
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SharedBoxCareHistoryPage(
                          api: api!,
                          boxId: box,
                          label: 'Test Box',
                          change: (operation) async {
                            await operation();
                            return true;
                          },
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Open care'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open care'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.boxCareEmpty), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-box-care-event')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('box-care-time')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('box-care-notes')),
        'Created',
      );
      await tester.tap(find.byKey(const Key('save-box-care-event')));
      await tester.pumpAndSettle();
      final entry = (await care.history(box)).single;
      expect(entry.notes, 'Created');
      await tester.tap(find.byKey(ValueKey('edit-box-care-${entry.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('box-care-notes')), 'Edited');
      await tester.tap(find.byKey(const Key('save-box-care-event')));
      await tester.pumpAndSettle();
      expect((await care.history(box)).single.notes, 'Edited');
      final delete = find.byKey(ValueKey('delete-box-care-${entry.id}'));
      if (mode == 'shared-caregiver') {
        expect(delete, findsNothing);
      } else {
        await tester.tap(delete);
        await tester.pumpAndSettle();
        expect(find.text(l10n.boxCareDeleteConfirm), findsOneWidget);
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        expect(await care.history(box), hasLength(1));
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.delete),
          ),
        );
        await tester.pumpAndSettle();
        expect(await care.history(box), isEmpty);
        expect(find.text(l10n.boxCareEmpty), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
