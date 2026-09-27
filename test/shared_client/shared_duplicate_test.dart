import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_collection_pages.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final animalMode in [false, true]) {
    testWidgets(
      '${animalMode ? 'Animal' : 'Box'} duplication submits once, refreshes and leaves original intact',
      (tester) async {
        final reply = Completer<http.Response>();
        var writes = 0;
        var reloads = 0;
        final boxes = <Map<String, dynamic>>[
          {'id': 1, 'name': 'Original Box', 'status': 'active'},
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
              expect(body[animalMode ? 'commonName' : 'name'], 'Chosen copy');
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
        await tester.enterText(
          find.byKey(const Key('duplicate-name')),
          'Chosen copy',
        );
        if (animalMode) {
          await tester.tap(find.byKey(const Key('duplicate-destination-box')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Destination · Box 2').last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('confirm-shared-duplicate')));
        await tester.pump();
        expect(writes, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('confirm-shared-duplicate')),
              )
              .onPressed,
          isNull,
        );
        final copy = animalMode
            ? {
                ...animals.first,
                'id': 3,
                'commonName': 'Chosen copy',
                'boxId': 2,
              }
            : {...boxes.first, 'id': 3, 'name': 'Chosen copy'};
        (animalMode ? animals : boxes).add(copy);
        reply.complete(
          http.Response(jsonEncode({animalMode ? 'animal' : 'box': copy}), 201),
        );
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(reloads, 1);
        expect(find.text('Chosen copy'), findsOneWidget);
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
