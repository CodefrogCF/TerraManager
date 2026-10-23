import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_boxes_page.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

void main() {
  for (final shared in [false, true]) {
    for (final animalsView in [false, true]) {
      for (final bigPictures in [false, true]) {
        testWidgets(
          '${shared ? 'Shared Care' : 'Standalone'} ${animalsView ? 'Animals' : 'Boxes'} '
          '${bigPictures ? 'grid' : 'list'} frees the last context menu',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final settings = AppSettingsController();
            addTearDown(settings.dispose);
            await settings.setBigPictureModeEnabled(bigPictures);
            final database = AppDatabase.test(NativeDatabase.memory());
            addTearDown(database.close);
            final api = SharedApiClient(
              Uri.parse('https://test.local'),
              MockClient((_) async => http.Response('{}', 404)),
            );
            addTearDown(api.close);
            final boxes = <Map<String, dynamic>>[];
            final animals = <Map<String, dynamic>>[];
            for (var i = 1; i <= 14; i++) {
              final boxId = shared
                  ? i
                  : await BoxRepository(database)
                        .createBoxWithGeneratedQrId(name: 'Box $i');
              final animalId = shared
                  ? i
                  : await AnimalRepository(database).createAnimal(
                      boxId: boxId,
                      commonName: 'Animal $i',
                      latinName: 'Species',
                      tempMin: 20,
                      tempMax: 28,
                      humidityMin: 40,
                      humidityMax: 70,
                    );
              boxes.add({'id': boxId, 'name': 'Box $i', 'status': 'active'});
              animals.add({
                'id': animalId,
                'boxId': boxId,
                'commonName': 'Animal $i',
                'latinName': 'Species',
                'status': 'active',
              });
            }
            Widget page() => shared
                ? animalsView
                      ? SharedAnimalsPage(
                          api: api,
                          boxes: boxes,
                          animals: animals,
                          connected: true,
                          change: (_) async => true,
                          onReload: () async {},
                        )
                      : SharedBoxesPage(
                          api: api,
                          boxes: boxes,
                          animals: animals,
                          connected: true,
                          change: (_) async => true,
                          onReload: () async {},
                        )
                : animalsView
                ? AnimalsPage(database: database)
                : BoxesPage(database: database);
            Widget view() => AppSettingsScope(
              controller: settings,
              child: MaterialApp(
                locale: const Locale('de'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: page(),
              ),
            );
            await tester.pumpWidget(view());
            await tester.pumpAndSettle();
            final add = find.byKey(
              Key(animalsView ? 'add-animal-button' : 'add-box-button'),
            );
            final secondary = find.byKey(
              Key(
                animalsView
                    ? shared
                          ? 'shared-feeding-mode-button'
                          : 'feeding-mode-button'
                    : shared
                    ? 'shared-box-scan-button'
                    : 'scan-box-button',
              ),
            );
            expect(add, findsOneWidget);
            expect(secondary, findsOneWidget);
            final scrollable = find
                .descendant(
                  of: find.byType(Scaffold).first,
                  matching: find.byType(Scrollable),
                )
                .first;
            final position = tester.state<ScrollableState>(scrollable).position;
            // Sliver builders refine their extent estimate while reaching the end.
            for (var i = 0; i < 4; i++) {
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
            }
            expect(position.extentAfter, 0);
            expect(add, findsNothing);
            expect(secondary, findsNothing);
            final menuPrefix = animalsView ? 'animal' : 'box';
            final menus = find.byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    '$menuPrefix-context-menu-button-',
                  ),
            );
            final lastMenu = menus.last;
            expect(lastMenu.hitTestable(), findsOneWidget);
            await tester.tap(lastMenu);
            await tester.pumpAndSettle();
            expect(
              find.byWidgetPredicate((widget) => widget is PopupMenuItem),
              findsWidgets,
            );
            await tester.tapAt(const Offset(10, 70));
            await tester.pumpAndSettle();
            position.jumpTo(position.maxScrollExtent - 100);
            await tester.pumpAndSettle();
            expect(add, findsOneWidget);
            expect(secondary, findsOneWidget);
            if (shared) {
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
              expect(add, findsNothing);
              boxes.clear();
              animals.clear();
              await tester.pumpWidget(view());
              await tester.pumpAndSettle();
              expect(add, findsOneWidget);
              expect(secondary, findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
