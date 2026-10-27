import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_care_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/care_event_type_repository.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/features/boxes/presentation/standalone_box_care_history.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_care_history_page.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_server/boxes/application/box_care_operations.dart';
import 'package:terramanager/shared_server/boxes/application/care_event_type_operations.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

void main() {
  for (final mode in ['standalone', 'shared']) {
    for (final language in ['de', 'en']) {
      testWidgets(
        '$mode $language manages custom types from history and preserves the selected filter on a narrow large-text screen',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final db = AppDatabase.test(NativeDatabase.memory());
          addTearDown(db.close);
          final types = CareEventTypeRepository(db);
          final care = BoxCareRepository(db);
          final box = await BoxRepository(db).createBoxWithGeneratedQrId();
          await care.add(
            boxId: box,
            type: BoxCareEventType.cleaning,
            occurredAt: DateTime.utc(2026),
            notes: 'Standard event',
          );
          SharedApiClient? api;
          if (mode == 'shared') {
            final operations = BoxCareOperations(db);
            final definitions = CareEventTypeOperations(db);
            api = SharedApiClient(
              Uri.parse('https://test.local'),
              MockClient((request) async {
                final path = request.url.path;
                if (path.endsWith('/login')) {
                  return http.Response(
                    jsonEncode({
                      'user': {'username': 'keeper', 'role': 'caregiver'},
                      'csrfToken': 'test-token',
                    }),
                    200,
                  );
                }
                if (path == '/api/v1/boxes/$box') {
                  return http.Response(
                    jsonEncode({
                      'box': {'id': box, 'status': 'active'},
                    }),
                    200,
                  );
                }
                final input = request.body.isEmpty
                    ? ApiInput({})
                    : ApiInput.decode(request.body);
                final ApiReply reply;
                if (path.startsWith('/api/v1/care-event-types')) {
                  if (request.method == 'GET') {
                    reply = await definitions.list();
                  } else if (request.method == 'POST') {
                    reply = await definitions.create(input);
                  } else if (path.endsWith('/order')) {
                    reply = await definitions.reorder(input);
                  } else {
                    reply = await definitions.update(
                      path.split('/').last,
                      input,
                    );
                  }
                } else {
                  if (request.method == 'GET') {
                    reply = await operations.list(box);
                  } else if (request.method == 'POST') {
                    reply = await operations.create(box, input);
                  } else {
                    reply = await operations.update(
                      box,
                      int.parse(path.split('/').last),
                      input,
                    );
                  }
                }
                return http.Response(jsonEncode(reply.body), reply.status);
              }),
            );
            addTearDown(api.close);
            await api.login('keeper', 'test password');
          }
          final l10n = lookupAppLocalizations(Locale(language));
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.6)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      TextButton(
                        key: const Key('history-open'),
                        onPressed: () {
                          if (api == null) {
                            openStandaloneBoxCareHistory(
                              context,
                              database: db,
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
                        child: const Text('History'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          Future<void> tap(Finder finder) async {
            await db.customSelect('SELECT 1').get();
            await tester.pumpAndSettle();
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }

          Future<void> add(String label) async {
            await tap(find.byKey(const Key('add-care-type')));
            await tester.enterText(
              find.byKey(const Key('care-type-label')),
              label,
            );
            await tap(find.byKey(const Key('save-care-type')));
            await db.customSelect('SELECT 1').get();
            await tester.pumpAndSettle();
          }

          await tap(find.byKey(const Key('history-open')));
          await tap(find.byKey(const Key('manage-care-types')));
          expect(find.text(l10n.careTypesEmpty), findsOneWidget);
          const label =
              'Belüftung und technische Ausstattung sorgfältig kontrollieren';
          await add(label);
          final original = (await types.all()).single;
          await tap(find.byKey(const Key('add-care-type')));
          await tester.enterText(
            find.byKey(const Key('care-type-label')),
            label.toUpperCase(),
          );
          await tap(find.byKey(const Key('save-care-type')));
          expect(find.text(l10n.careTypeDuplicate), findsOneWidget);
          await tap(find.text(l10n.cancel));
          await add('Lamp check');
          final second = (await types.all()).last;
          await tap(find.byKey(ValueKey('care-type-up-${second.id}')));
          expect((await types.all()).map((t) => t.id), [
            second.id,
            original.id,
          ]);
          await tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          await tap(find.byKey(const Key('add-box-care-event')));
          await tap(find.byKey(const Key('box-care-type')));
          await tap(find.text(label).last);
          await tester.enterText(
            find.byKey(const Key('box-care-notes')),
            'Custom event',
          );
          await tap(find.byKey(const Key('save-box-care-event')));
          final event = (await care.history(box)).first;
          expect(event.customTypeId, original.id);
          await tap(find.byKey(const Key('box-care-filter')));
          await tap(find.text(label).last);
          expect(find.text('Standard event'), findsNothing);
          await tap(find.byKey(const Key('manage-care-types')));
          await tap(find.byKey(ValueKey('rename-care-type-${original.id}')));
          await tester.enterText(
            find.byKey(const Key('care-type-label')),
            'Renamed ventilation',
          );
          await tap(find.byKey(const Key('save-care-type')));
          await tap(find.byKey(ValueKey('archive-care-type-${original.id}')));
          expect(find.text(l10n.careTypeArchiveHint), findsOneWidget);
          await tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(l10n.archive),
            ),
          );
          expect((await types.byId(original.id))!.archived, true);
          expect((await care.history(box)).first.customTypeId, original.id);
          await tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(
            find.text('Renamed ventilation (${l10n.archived})'),
            findsOneWidget,
          );
          expect(find.text('Standard event'), findsNothing);
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('box-care-event-${event.id}')),
            160,
          );
          expect(find.text('Custom event'), findsOneWidget);
          expect(find.text('Renamed ventilation'), findsOneWidget);
          await tap(find.byKey(const Key('add-box-care-event')));
          final dropdown = tester.widget<DropdownButton<String>>(
            find.descendant(
              of: find.byKey(const Key('box-care-type')),
              matching: find.byType(DropdownButton<String>),
            ),
          );
          expect(
            dropdown.items!.map((item) => item.value),
            isNot(contains(original.id)),
          );
          await tap(find.text(l10n.cancel));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
