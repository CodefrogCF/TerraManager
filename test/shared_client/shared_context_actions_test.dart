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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final animals in [false, true]) {
    for (final bigPictures in [false, true]) {
      testWidgets(
        '${animals ? 'Animal' : 'Box'} active menu keeps Edit, Duplicate and Archive without Rename in ${bigPictures ? 'pictures' : 'list'}',
        (tester) async {
          final settings = AppSettingsController();
          final currentAnimal = <String, dynamic>{
            'id': 2,
            'boxId': 1,
            'status': 'active',
            'commonName': 'Current',
            'latinName': 'Species',
            'revision': 'opened',
            'category': 'other',
            'tempMin': 20,
            'tempMax': 30,
            'humidityMin': 40,
            'humidityMax': 60,
            'showWeightOnDetail': false,
            'showSheddingOnDetail': true,
          };
          final writes = <Map<String, dynamic>>[];
          final api = SharedApiClient(
            Uri.parse('https://localhost'),
            MockClient((request) async {
              if (request.url.path == '/api/v1/auth/login') {
                return http.Response(
                  jsonEncode({
                    'user': {'username': 'carer', 'role': 'caregiver'},
                    'csrfToken': 'csrf',
                  }),
                  200,
                );
              }
              if (request.url.path == '/api/v1/animals/2') {
                if (request.method == 'PUT') {
                  writes.add(jsonDecode(request.body) as Map<String, dynamic>);
                }
                return http.Response(
                  jsonEncode({'animal': currentAnimal}),
                  200,
                );
              }
              return http.Response('{}', 404);
            }),
          );
          addTearDown(settings.dispose);
          addTearDown(api.close);
          await api.login('carer', 'password');
          await settings.setBigPictureModeEnabled(bigPictures);
          const boxes = [
            {'id': 1, 'status': 'active', 'name': 'Box'},
          ];
          await tester.pumpWidget(
            AppSettingsScope(
              controller: settings,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: animals
                    ? SharedAnimalsPage(
                        api: api,
                        boxes: boxes,
                        animals: [currentAnimal],
                        connected: true,
                        change: (mutation) async {
                          await mutation();
                          return true;
                        },
                        onReload: () async {},
                      )
                    : SharedBoxesPage(
                        api: api,
                        boxes: boxes,
                        animals: const [],
                        connected: true,
                        change: (_) async => true,
                        onReload: () async {},
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final kind = animals ? 'Animal' : 'Box';
          await tester.tap(
            find.byKey(
              Key(
                '${animals ? 'animal' : 'box'}-context-menu-button-${animals ? 2 : 1}',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Rename $kind'), findsNothing);
          for (final action in ['Edit', 'Duplicate', 'Archive']) {
            expect(find.text('$action $kind'), findsOneWidget);
          }
          expect(find.text('Open details'), findsOneWidget);
          if (animals && !bigPictures) {
            await tester.tap(find.text('Edit Animal'));
            await tester.pumpAndSettle();
            final commonName = find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.decoration?.labelText == 'Common name',
            );
            await tester.enterText(commonName, '');
            await tester.pumpAndSettle();
            final save = find.byKey(const Key('shared-save-animal'));
            await tester.scrollUntilVisible(
              save,
              500,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            await tester.tap(save);
            await tester.pumpAndSettle();
            expect(writes, isEmpty);
            await tester.scrollUntilVisible(
              commonName,
              -500,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.enterText(commonName, 'Renamed');
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              save,
              500,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            await tester.tap(save);
            await tester.pumpAndSettle();
            expect(writes, hasLength(1));
            expect(writes.single['commonName'], 'Renamed');
            expect(writes.single['showWeightOnDetail'], isFalse);
            expect(writes.single['showSheddingOnDetail'], isTrue);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'archived Box context menu stays in a list when Big Picture is enabled',
    (tester) async {
      final settings = AppSettingsController();
      final api = SharedApiClient(
        Uri.parse('https://192.168.1.117'),
        MockClient((_) async => http.Response('{}', 404)),
      );
      addTearDown(settings.dispose);
      addTearDown(api.close);
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: SharedBoxesPage(
              api: api,
              boxes: const [
                {'id': 1, 'name': 'Archive', 'status': 'archived'},
              ],
              animals: const [],
              connected: true,
              change: (_) async => true,
              onReload: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('box-archive-button')));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('box-context-menu-button-1'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Open details'), findsOneWidget);
      expect(find.text('Rename Box'), findsNothing);
      expect(find.text('Restore Box'), findsOneWidget);
      expect(find.text('Delete Box'), findsNothing);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      await settings.setBigPictureModeEnabled(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('box-big-picture-1')), findsNothing);
      expect(find.byKey(const Key('box-list-item-1')), findsOneWidget);
      await tester.longPress(
        find.byKey(const Key('box-context-menu-region-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Restore Box'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('archived Animal menu offers restore without permanent delete', (
    tester,
  ) async {
    final settings = AppSettingsController();
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((_) async => http.Response('{}', 404)),
    );
    addTearDown(settings.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SharedAnimalsPage(
            api: api,
            boxes: const [
              {'id': 1, 'status': 'active'},
            ],
            animals: const [
              {
                'id': 2,
                'commonName': 'Archive',
                'status': 'archived',
                'boxId': 1,
              },
            ],
            connected: true,
            change: (_) async => true,
            onReload: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('animal-history-button')));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('animal-context-menu-button-2'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Open details'), findsOneWidget);
    expect(find.text('Rename Animal'), findsNothing);
    expect(find.text('Restore Animal'), findsOneWidget);
    expect(find.text('Delete Animal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
