import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_boxes_page.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final (description, animalMode, archived, name) in [
    ('Named Box', false, false, 'Chosen copy'),
    ('Active Box with a blank name', false, false, ''),
    ('Archived Box with a whitespace-only name', false, true, '   '),
    ('Named Animal', true, false, 'Chosen copy'),
  ]) {
    testWidgets(
      '$description duplication submits once, refreshes and leaves original intact',
      (tester) async {
        final savedName = name.trim().isEmpty ? null : name;
        final reply = Completer<http.Response>();
        var writes = 0;
        var reloads = 0;
        final boxes = <Map<String, dynamic>>[
          {
            'id': 1,
            'name': 'Original Box',
            'status': archived ? 'archived' : 'active',
          },
          {'id': 2, 'name': 'Destination', 'status': 'active'},
        ];
        final animals = <Map<String, dynamic>>[
          {
            'id': 1,
            'commonName': 'Original Animal',
            'latinName': 'Species',
            'boxId': 1,
            'status': 'active',
          },
        ];
        final api = SharedApiClient(
          Uri.parse('https://test.local'),
          MockClient((request) async {
            if (request.url.path.endsWith('/login')) {
              return http.Response(
                '{"user":{"username":"carer","role":"caregiver"},"csrfToken":"token"}',
                200,
              );
            }
            if (request.url.path.endsWith('/duplicate')) {
              writes++;
              final body = jsonDecode(request.body);
              expect(
                body,
                containsPair(animalMode ? 'commonName' : 'name', savedName),
              );
              if (animalMode) expect(body['boxId'], 2);
              return reply.future;
            }
            return http.Response('{}', 404);
          }),
        );
        await api.login('carer', 'password');
        final settings = AppSettingsController();
        addTearDown(api.close);
        addTearDown(settings.dispose);
        Future<bool> change(Future<void> Function() operation) async {
          try {
            await operation();
            return true;
          } catch (_) {
            return false;
          }
        }

        await tester.pumpWidget(
          AppSettingsScope(
            controller: settings,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: animalMode
                  ? SharedAnimalsPage(
                      api: api,
                      boxes: boxes,
                      animals: animals,
                      connected: true,
                      change: change,
                      onReload: () async {
                        reloads++;
                      },
                    )
                  : SharedBoxesPage(
                      api: api,
                      boxes: boxes,
                      animals: animals,
                      connected: true,
                      change: change,
                      onReload: () async {
                        reloads++;
                      },
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (archived) {
          await tester.tap(find.byKey(const Key('box-archive-button')));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.byKey(
            Key('${animalMode ? 'animal' : 'box'}-context-menu-button-1'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(animalMode ? 'Duplicate Animal' : 'Duplicate Box'),
        );
        await tester.pumpAndSettle();
        final nameField = find.byKey(const Key('duplicate-name'));
        final confirm = find.byKey(const Key('confirm-shared-duplicate'));
        if (animalMode) {
          await tester.enterText(nameField, '   ');
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(find.text('Enter a name.'), findsOneWidget);
          expect(writes, 0);
        }
        await tester.enterText(nameField, name);
        if (animalMode) {
          await tester.tap(find.byKey(const Key('duplicate-destination-box')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Destination · Box 2').last);
          await tester.pumpAndSettle();
        }
        await tester.tap(confirm);
        await tester.pump();
        expect(writes, 1);
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        final copy = animalMode
            ? {...animals.first, 'id': 3, 'commonName': savedName, 'boxId': 2}
            : {...boxes.first, 'id': 3, 'name': savedName, 'status': 'active'};
        (animalMode ? animals : boxes).add(copy);
        reply.complete(
          http.Response(jsonEncode({animalMode ? 'animal' : 'box': copy}), 201),
        );
        await tester.pumpAndSettle();
        if (archived) {
          expect(find.text('Original Box'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        expect(writes, 1);
        expect(reloads, 1);
        expect(find.text(savedName ?? 'Box 3'), findsOneWidget);
        expect(boxes.first['name'], 'Original Box');
        expect(animals.first['commonName'], 'Original Animal');
        expect(find.byKey(const Key('duplicate-error')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'duplication permission failure remains visible without false success',
    (tester) async {
      final api = SharedApiClient(
        Uri.parse('https://test.local'),
        MockClient(
          (request) async => request.url.path.endsWith('/login')
              ? http.Response(
                  '{"user":{"username":"carer","role":"caregiver"},"csrfToken":"token"}',
                  200,
                )
              : http.Response(
                  '{"error":{"code":"forbidden","message":"Denied"}}',
                  403,
                ),
        ),
      );
      await api.login('carer', 'password');
      final settings = AppSettingsController();
      addTearDown(api.close);
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SharedBoxesPage(
              api: api,
              boxes: const [
                {'id': 1, 'name': 'Original', 'status': 'active'},
              ],
              animals: const [],
              connected: true,
              change: (operation) async {
                try {
                  await operation();
                  return true;
                } catch (_) {
                  return false;
                }
              },
              onReload: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('box-context-menu-button-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate Box'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-shared-duplicate')));
      await tester.pumpAndSettle();
      expect(
        find.text('You do not have permission to duplicate this record.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('confirm-shared-duplicate')), findsOneWidget);
    },
  );
}
