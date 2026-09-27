import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/new_animal_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_scanner_page.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_box_scanner_page.dart';
import 'package:terramanager/shared_client/shared_detail_pages.dart';
import 'package:terramanager/shared_client/shared_forms.dart';

const _boxes = [
  {'id': 1, 'status': 'active', 'name': 'First'},
  {'id': 2, 'status': 'active', 'name': 'Scanned'},
];
const _animal = {
  'id': 9,
  'boxId': 1,
  'status': 'active',
  'revision': 'original',
  'commonName': 'Animal',
  'latinName': 'Species',
  'category': 'other',
  'tempMin': 20,
  'tempMax': 30,
  'humidityMin': 40,
  'humidityMax': 60,
  'showWeightOnDetail': false,
  'showSheddingOnDetail': true,
};

Future<void> _openForm(WidgetTester tester, Widget form) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push<bool>(MaterialPageRoute(builder: (_) => form)),
            child: const Text('Open form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}

Future<SharedApiClient> _client(
  Future<http.Response> Function(http.Request) handle,
) async {
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
      return handle(request);
    }),
  );
  await api.login('carer', 'password');
  return api;
}

void main() {
  testWidgets(
    'saving visibility updates Animal details and re-enabling shows the existing measurements',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettingsController();
      addTearDown(settings.dispose);
      Map<String, dynamic> animal = {..._animal, 'showWeightOnDetail': true};
      final methods = <String>[];
      final api = await _client((request) async {
        methods.add(request.method);
        final path = request.url.path;
        if (path == '/api/v1/animals/9') {
          if (request.method == 'PUT') {
            animal = {
              ...animal,
              ...jsonDecode(request.body) as Map<String, dynamic>,
              'revision': 'saved',
            };
          }
          return http.Response(jsonEncode({'animal': animal}), 200);
        }
        if (path.endsWith('/weights')) {
          return http.Response(
            jsonEncode({
              'weights': [
                {
                  'id': 1,
                  'animalId': 9,
                  'weightGrams': 12.5,
                  'measuredAt': '2026-07-01T17:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/shedding')) {
          return http.Response(
            jsonEncode({
              'shedding': [
                {
                  'id': 2,
                  'animalId': 9,
                  'shedAt': '2026-07-02T17:00:00Z',
                  'notes': 'Existing',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'boxes': _boxes, 'pictures': [], 'feedings': []}),
          200,
        );
      });
      addTearDown(api.close);
      Future<void> mountDetail() => tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            home: SharedAnimalDetailPage(
              key: UniqueKey(),
              api: api,
              id: 9,
              boxes: _boxes,
              connected: true,
              change: (mutation) async {
                await mutation();
                return true;
              },
            ),
          ),
        ),
      );
      Future<void> toggleAndSave() async {
        await tester.tap(find.byTooltip('Edit Animal'));
        await tester.pumpAndSettle();
        final weight = find.byKey(const Key('shared-show-weight-on-detail'));
        await tester.scrollUntilVisible(
          weight,
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(weight);
        await tester.tap(
          find.byKey(const Key('shared-show-shedding-on-detail')),
        );
        final save = find.byKey(const Key('shared-save-animal'));
        await tester.scrollUntilVisible(
          save,
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
      }

      await mountDetail();
      await tester.pumpAndSettle();
      await toggleAndSave();
      expect(animal['showWeightOnDetail'], isFalse);
      expect(animal['showSheddingOnDetail'], isFalse);
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shared-weight-detail')), findsNothing);
      expect(find.byKey(const Key('shared-shedding-detail')), findsNothing);
      await mountDetail();
      await tester.pumpAndSettle();
      await toggleAndSave();
      final weightDetail = find.byKey(const Key('shared-weight-detail'));
      await tester.scrollUntilVisible(
        weightDetail,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(weightDetail, findsOneWidget);
      expect(find.byKey(const Key('shared-shedding-detail')), findsOneWidget);
      expect(methods.where((method) => method != 'GET'), ['PUT', 'PUT']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'standalone QR selection ${cancel ? 'cancel preserves' : 'changes only'} the draft',
      (tester) async {
        final db = AppDatabase.test(NativeDatabase.memory());
        addTearDown(db.close);
        final boxes = BoxRepository(db);
        final first = await boxes.createBoxWithGeneratedQrId(name: 'First');
        final target = await boxes.createBoxWithGeneratedQrId(name: 'Scanned');
        await _openForm(
          tester,
          NewAnimalPage(database: db, initialBoxId: first),
        );
        for (final field in {
          'common-name-field': 'Draft',
          'latin-name-field': 'Draft species',
          'temp-min-field': '20',
          'temp-max-field': '30',
          'humidity-min-field': '40',
          'humidity-max-field': '60',
        }.entries) {
          await tester.enterText(find.byKey(Key(field.key)), field.value);
        }
        final button = find.byKey(const Key('new-animal-scan-box-button'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(BoxScannerPage), findsOneWidget);
        expect(find.text('Rehouse Mode'), findsNothing);
        if (!cancel) {
          final scanner = tester.widget<BoxScannerPage>(
            find.byType(BoxScannerPage),
          );
          expect(
            await scanner.onBoxScanned!((await boxes.getBoxById(target))!),
            isTrue,
          );
          Navigator.of(tester.element(find.byType(BoxScannerPage))).pop(true);
        } else {
          await tester.pageBack();
        }
        await tester.pumpAndSettle();
        expect(
          tester
              .state<FormFieldState<int>>(find.byKey(const Key('box-field')))
              .value,
          cancel ? first : target,
        );
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('common-name-field')))
              .controller!
              .text,
          'Draft',
        );
        expect(await AnimalRepository(db).getAllAnimals(), isEmpty);
        expect(await db.select(db.feedingEvents).get(), isEmpty);
        if (!cancel) {
          await tester.ensureVisible(
            find.byKey(const Key('create-animal-button')),
          );
          await tester.tap(find.byKey(const Key('create-animal-button')));
          await tester.pumpAndSettle();
          final animals = await AnimalRepository(db).getAllAnimals();
          expect(animals, hasLength(1));
          expect(animals.single.boxId, target);
          expect(animals.single.commonName, 'Draft');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a scanned standalone Box removed before selection cannot change the draft',
    (tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BoxRepository(db);
      final first = await repo.createBoxWithGeneratedQrId();
      final target = await repo.createBoxWithGeneratedQrId();
      final openedTarget = (await repo.getBoxById(target))!;
      await _openForm(tester, NewAnimalPage(database: db, initialBoxId: first));
      await tester.tap(find.byKey(const Key('new-animal-scan-box-button')));
      await tester.pumpAndSettle();
      await (db.delete(db.boxes)..where((row) => row.id.equals(target))).go();
      final scanner = tester.widget<BoxScannerPage>(
        find.byType(BoxScannerPage),
      );
      expect(await scanner.onBoxScanned!(openedTarget), isFalse);
      await tester.pump();
      expect(
        find.text(
          'The selected Box is no longer active. Select another active Box.',
        ),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .state<FormFieldState<int>>(find.byKey(const Key('box-field')))
            .value,
        first,
      );
      expect(await AnimalRepository(db).getAllAnimals(), isEmpty);
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'Shared Care QR ${cancel ? 'cancellation preserves' : 'selection updates'} the draft without writes',
      (tester) async {
        final writes = <http.Request>[];
        final api = await _client((request) async {
          if (request.method != 'GET') writes.add(request);
          if (request.url.path == '/api/v1/boxes') {
            return http.Response(jsonEncode({'boxes': _boxes}), 200);
          }
          if (request.url.path == '/api/v1/animals' &&
              request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'animal': {'id': 9},
              }),
              201,
            );
          }
          return http.Response('{}', 404);
        });
        addTearDown(api.close);
        await _openForm(
          tester,
          SharedAnimalForm(
            api: api,
            boxes: _boxes,
            change: (mutation) async {
              await mutation();
              return true;
            },
          ),
        );
        await tester.enterText(find.byType(TextFormField).at(0), 'Draft');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Draft species',
        );
        await tester.tap(
          find.byKey(const Key('shared-new-animal-scan-box-button')),
        );
        await tester.pumpAndSettle();
        if (cancel) {
          await tester.pageBack();
        } else {
          final scanner = tester.widget<SharedBoxScannerPage>(
            find.byType(SharedBoxScannerPage),
          );
          await scanner.onBoxResolved!(
            tester.element(find.byType(SharedBoxScannerPage)),
            _boxes[1],
          );
        }
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
        expect(
          find.byKey(Key('shared-animal-box-${cancel ? 1 : 2}')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Draft',
        );
        if (!cancel) {
          await tester.scrollUntilVisible(
            find.byKey(const Key('shared-save-animal')),
            500,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.byKey(const Key('shared-save-animal')));
          await tester.pumpAndSettle();
          expect(writes, hasLength(1));
          expect(writes.single.url.path, '/api/v1/animals');
          expect((jsonDecode(writes.single.body) as Map)['boxId'], 2);
          expect(
            (jsonDecode(writes.single.body) as Map)['commonName'],
            'Draft',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Shared Care rejects a scanned Box absent from the selectable server list',
    (tester) async {
      final api = await _client(
        (_) async => http.Response(
          jsonEncode({
            'boxes': [_boxes.first],
          }),
          200,
        ),
      );
      addTearDown(api.close);
      await _openForm(
        tester,
        SharedAnimalForm(
          api: api,
          boxes: _boxes,
          change: (_) async => throw StateError('No write allowed'),
        ),
      );
      await tester.tap(
        find.byKey(const Key('shared-new-animal-scan-box-button')),
      );
      await tester.pumpAndSettle();
      final scanner = tester.widget<SharedBoxScannerPage>(
        find.byType(SharedBoxScannerPage),
      );
      expect(
        await scanner.onBoxResolved!(
          tester.element(find.byType(SharedBoxScannerPage)),
          _boxes[1],
        ),
        isFalse,
      );
      await tester.pump();
      expect(find.byType(SharedBoxScannerPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shared-animal-box-1')), findsOneWidget);
    },
  );

  testWidgets(
    'Edit Animal saves independent visibility settings and reloads their saved values',
    (tester) async {
      Map<String, dynamic> animal = {..._animal};
      var writes = 0;
      final api = await _client((request) async {
        expect(request.url.path, '/api/v1/animals/9');
        if (request.method == 'PUT') {
          writes++;
          animal = {
            ...animal,
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'revision': 'saved',
          };
        }
        return http.Response(jsonEncode({'animal': animal}), 200);
      });
      addTearDown(api.close);
      Future<void> open() => _openForm(
        tester,
        SharedAnimalForm(
          api: api,
          boxes: _boxes,
          initial: animal,
          change: (mutation) async {
            await mutation();
            return true;
          },
        ),
      );
      await open();
      final weight = find.byKey(const Key('shared-show-weight-on-detail'));
      final shedding = find.byKey(const Key('shared-show-shedding-on-detail'));
      await tester.scrollUntilVisible(
        weight,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<SwitchListTile>(weight).value, isFalse);
      expect(tester.widget<SwitchListTile>(shedding).value, isTrue);
      await tester.ensureVisible(weight);
      await tester.tap(weight);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(shedding).value, isTrue);
      await tester.ensureVisible(shedding);
      await tester.tap(shedding);
      await tester.scrollUntilVisible(
        find.byKey(const Key('shared-save-animal')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('shared-save-animal')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(animal['showWeightOnDetail'], isTrue);
      expect(animal['showSheddingOnDetail'], isFalse);
      await open();
      await tester.scrollUntilVisible(
        weight,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<SwitchListTile>(weight).value, isTrue);
      expect(tester.widget<SwitchListTile>(shedding).value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
