// Explicit asset-generation tool; not part of the ordinary regression suite.
// Run: flutter test --no-pub tool/store_presence/capture_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_category.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/core/theme/app_theme.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/new_animal_page.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_history_page.dart';
import 'package:terramanager/features/media/presentation/pages/picture_gallery_page.dart';
import 'package:terramanager/features/navigation/presentation/pages/app_shell.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

const _root = 'marketing/play-store';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final flutterRoot =
        Platform.environment['STORE_FLUTTER_ROOT'] ??
        Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) {
      throw StateError('Set STORE_FLUTTER_ROOT to your Flutter SDK directory.');
    }
    final font = FontLoader('Roboto');
    for (final weight in ['regular', 'bold', 'medium']) {
      final bytes = await File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/roboto-$weight.ttf',
      ).readAsBytes();
      font.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons');
    final iconBytes = await File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    icons.addFont(Future.value(ByteData.sublistView(iconBytes)));
    await icons.load();
  });

  for (final language in ['de', 'en']) {
    testWidgets(
      'capture real standalone pages with $language demonstration data',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final originalShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          tester.view.physicalSize = const Size(1080, 1614);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          // This explicit Flutter test tool lives outside the normal test suite.
          // ignore: invalid_use_of_visible_for_testing_member
          SharedPreferences.setMockInitialValues({
            'standalone_tutorial_seen': true,
          });
          final german = language == 'de';
          final database = AppDatabase.test(NativeDatabase.memory());
          addTearDown(database.close);
          final settings = AppSettingsController();
          settings.applyStoredSettings({
            'theme_mode': 'light',
            'accent_color': 'green',
            'language': german ? 'german' : 'english',
            'next_feeding_summary_enabled': true,
          });
          addTearDown(settings.dispose);
          final boxes = BoxRepository(database);
          final boxId = await boxes.createBox(
            'TM:BOX:ffffffff-ffff-4fff-8fff-fffffffffff1',
            name: german ? 'Waldterrarium' : 'Forest terrarium',
            widthCm: 40,
            heightCm: 40,
            depthCm: 40,
            notes: german
                ? 'Beispieldaten – keine Haltungsanleitung.'
                : 'Demo data – not husbandry advice.',
          );
          final secondBox = await boxes.createBox(
            'TM:BOX:ffffffff-ffff-4fff-8fff-fffffffffff2',
            name: german ? 'Wüstenterrarium' : 'Desert terrarium',
            widthCm: 60,
            heightCm: 40,
            depthCm: 40,
          );
          await boxes.createBox(
            'TM:BOX:ffffffff-ffff-4fff-8fff-fffffffffff3',
            name: german ? 'Aufzuchtbox' : 'Nursery Box',
            widthCm: 20,
            heightCm: 25,
            depthCm: 20,
          );
          final animalId = await AnimalRepository(database).createAnimal(
            boxId: boxId,
            commonName: 'Luna',
            latinName: 'Brachypelma hamorii',
            category: AnimalCategory.arachnid,
            subcategory: AnimalSubcategory.tarantula,
            tempMin: 20,
            tempMax: 26,
            humidityMin: 50,
            humidityMax: 65,
            feedingReminderIntervalDays: 7,
            feedingReminderBaseline: DateTime(2026, 9, 1, 19),
            showWeightOnDetail: false,
            showSheddingOnDetail: false,
          );
          final secondAnimal = await AnimalRepository(database).createAnimal(
            boxId: secondBox,
            commonName: 'Milo',
            latinName: 'Eublepharis macularius',
            category: AnimalCategory.reptile,
            subcategory: AnimalSubcategory.lizard,
            tempMin: 24,
            tempMax: 30,
            humidityMin: 40,
            humidityMax: 50,
            feedingReminderIntervalDays: 7,
            feedingReminderBaseline: DateTime(2026, 9, 26, 18),
          );
          final gallery = PictureGalleryRepository(database);
          for (var i = 1; i <= 3; i++) {
            await gallery.addAnimalPicture(
              animalId: animalId,
              fileName: 'demo-luna-$i.png',
              mimeType: 'image/png',
              data: File('$_root/source/demo-images/luna-$i.png')
                  .readAsBytesSync(),
              capturedAt: DateTime(2026, 9, 10 + i, 12),
              makePrimary: i == 1,
            );
          }
          final gecko = File('$_root/source/demo-images/milo.png')
              .readAsBytesSync();
          await gallery.addAnimalPicture(
            animalId: secondAnimal,
            fileName: 'demo-milo.png',
            mimeType: 'image/png',
            data: gecko,
          );
          await gallery.addBoxPicture(
            boxId: secondBox,
            fileName: 'demo-desert.png',
            mimeType: 'image/png',
            data: gecko,
          );
          await gallery.addBoxPicture(
            boxId: boxId,
            fileName: 'demo-forest.png',
            mimeType: 'image/png',
            data: File('$_root/source/demo-images/terrarium.png')
                .readAsBytesSync(),
          );
          for (final day in [4, 11, 18, 20]) {
            await FeedingRepository(database).addFeeding(
              animalId,
              DateTime(2026, 9, day, 19),
              notes: german
                  ? 'Fütterung dokumentiert (Beispiel).'
                  : 'Feeding recorded (demo).',
            );
          }
          final navigator = GlobalKey<NavigatorState>();
          final boundary = GlobalKey();

          Future<void> pumpPage([Widget? page, String? section]) async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: AppSettingsScope(
                  controller: settings,
                  child: MaterialApp(
                    key: UniqueKey(),
                    navigatorKey: navigator,
                    debugShowCheckedModeBanner: false,
                    locale: Locale(language),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: AppTheme.lightTheme(
                      seedColor: AppAccent.green.color,
                    ),
                    home: AppShell(database: database),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (section != null) {
              await tester.tap(
                find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text(section),
                ),
              );
              await tester.pumpAndSettle();
            }
            if (page != null) {
              navigator.currentState!.push(
                MaterialPageRoute<void>(builder: (_) => page),
              );
              await tester.pumpAndSettle();
            }
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pumpAndSettle();
          }

          Future<void> capture(String id) async {
            expect(tester.takeException(), isNull, reason: id);
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 3);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('$_root/source/captures/$language/$id.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
              stdout.writeln('Captured $language/$id');
            });
          }

          Future<void> position(Key key, {double alignment = 0.05}) async {
            if (find.byKey(key).evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                find.byKey(key),
                220,
                scrollable: find.byType(Scrollable).last,
              );
            }
            await tester.ensureVisible(find.byKey(key));
            await Scrollable.ensureVisible(
              tester.element(find.byKey(key)),
              alignment: alignment,
            );
            await tester.pumpAndSettle();
          }

          await pumpPage();
          await capture('01-boxes');
          await pumpPage(
            AnimalDetailPage(database: database, animalId: animalId),
          );
          await tester.ensureVisible(find.text('Luna').last);
          await Scrollable.ensureVisible(
            tester.element(find.text('Luna').last),
            alignment: 0.05,
          );
          await tester.pumpAndSettle();
          await capture('02-animal');
          await pumpPage(
            FeedingHistoryPage(database: database, animalId: animalId),
          );
          await capture('03-feeding');
          await pumpPage(null, german ? 'Tiere' : 'Animals');
          await capture('04-reminders');
          await pumpPage(
            BoxDetailPage(
              database: database,
              box: (await boxes.getBoxById(boxId))!,
            ),
          );
          await position(const Key('box-qr-section-heading'));
          await capture('05-box-qr');
          await pumpPage(
            NewAnimalPage(database: database, initialBoxId: boxId),
          );
          await tester.enterText(
            find.byKey(const Key('common-name-field')),
            'Nori',
          );
          await tester.enterText(
            find.byKey(const Key('latin-name-field')),
            'Correlophus ciliatus',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await position(const Key('box-field'));
          await capture('06-new-animal');
          await pumpPage(
            PictureGalleryPage(
              database: database,
              owner: PictureGalleryOwner.animal,
              ownerId: animalId,
            ),
          );
          await capture('07-pictures');
          await pumpPage(null, german ? 'Einstellungen' : 'Settings');
          await tester.scrollUntilVisible(
            find.byKey(const Key('backup-section-heading')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await position(const Key('backup-section-heading'), alignment: 0.35);
          await capture('08-backups');

          final backup = await BackupExportService(database).createBackup(
            appVersion: '1.14.3',
            themeMode: ThemeMode.light,
            accent: AppAccent.green,
            language: german ? AppLanguage.german : AppLanguage.english,
            nextFeedingSummaryEnabled: true,
            createdAt: DateTime.utc(2026, 9, 27, 12),
          );
          final file = File('$_root/source/demo-collection-$language.tmbackup');
          file.writeAsBytesSync(backup.bytes);
          if (language == 'en') {
            final databaseFile = File('$_root/source/device-demo.sqlite');
            if (databaseFile.existsSync()) databaseFile.deleteSync();
            final path = databaseFile.absolute.path.replaceAll("'", "''");
            await database.customStatement("VACUUM INTO '$path'");
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        } finally {
          debugDefaultTargetPlatformOverride = null;
          debugDisableShadows = originalShadows;
        }
      },
    );
  }
}
