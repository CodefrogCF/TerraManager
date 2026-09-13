import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_edit_page.dart';
import 'package:terramanager/features/animals/presentation/pages/new_animal_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_scanner_page.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_box_animals_page.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_scanner_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase database;
  late BoxRepository boxes;
  late AnimalRepository animals;
  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    boxes = BoxRepository(database);
    animals = AnimalRepository(database);
  });
  tearDown(() => database.close());

  Future<void> archive(int id) async {
    await boxes.archiveBox(
      boxId: id,
      reason: BoxArchiveReason.replaced,
      archivedAt: DateTime(2026, 9, 13),
    );
  }

  Future<int> createAnimal(int boxId) => animals.createAnimal(
    boxId: boxId,
    commonName: 'Snake',
    latinName: 'Test species',
    tempMin: 20,
    tempMax: 30,
    humidityMin: 40,
    humidityMax: 60,
  );

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: page,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final control in ['new', 'edit', 'restore']) {
    testWidgets('$control Animal assignment only offers active Boxes', (
      tester,
    ) async {
      final activeId = await boxes.createBoxWithGeneratedQrId();
      final archivedId = await boxes.createBoxWithGeneratedQrId();
      await archive(archivedId);
      final animalId = await createAnimal(activeId);
      if (control == 'restore') {
        await animals.archiveAnimal(
          animalId: animalId,
          reason: AnimalArchiveReason.sold,
          archivedAt: DateTime.now(),
        );
      }
      final Widget page = switch (control) {
        'new' => NewAnimalPage(database: database, initialBoxId: archivedId),
        'edit' => AnimalEditPage(database: database, animalId: animalId),
        _ => AnimalDetailPage(database: database, animalId: animalId),
      };
      await pumpPage(tester, page);
      if (control == 'restore') {
        await tester.scrollUntilVisible(
          find.byKey(const Key('restore-animal-button')),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('restore-animal-button')));
        await tester.pumpAndSettle();
      }
      final field = tester.widget<DropdownButtonFormField<int>>(
        find.byType(DropdownButtonFormField<int>),
      );
      final dropdown = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      expect(dropdown.items!.map((item) => item.value), [activeId]);
      if (control == 'new') expect(field.initialValue, isNull);
    });
  }

  for (final hasFallback in [true, false]) {
    testWidgets(
      'stale New Animal form preserves draft with fallback: $hasFallback',
      (tester) async {
        final targetId = await boxes.createBoxWithGeneratedQrId();
        final fallbackId = hasFallback
            ? await boxes.createBoxWithGeneratedQrId()
            : null;
        await pumpPage(
          tester,
          NewAnimalPage(database: database, initialBoxId: targetId),
        );
        for (final entry in {
          'common-name-field': 'Draft Animal',
          'latin-name-field': 'Draft species',
          'temp-min-field': '20',
          'temp-max-field': '30',
          'humidity-min-field': '40',
          'humidity-max-field': '60',
        }.entries) {
          await tester.enterText(find.byKey(Key(entry.key)), entry.value);
        }
        await archive(targetId);
        await tester.tap(find.byKey(const Key('save-animal-button')));
        await tester.pumpAndSettle();
        expect(await animals.getAllAnimals(), isEmpty);
        expect(
          find.text(
            'The selected Box is no longer active. Select another active Box.',
          ),
          findsOneWidget,
        );
        final field = tester.widget<DropdownButtonFormField<int>>(
          find.byType(DropdownButtonFormField<int>),
        );
        expect(field.initialValue, isNull);
        final dropdown = tester.widget<DropdownButton<int>>(
          find.byType(DropdownButton<int>),
        );
        expect(dropdown.items!.map((item) => item.value), [
          if (hasFallback) fallbackId,
        ]);
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('common-name-field')))
              .controller!
              .text,
          'Draft Animal',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final feeding in [false, true]) {
    for (final language in ['en', 'de']) {
      testWidgets(
        '${feeding ? 'Feeding' : 'Box'} scanner rejects archived QR in $language and accepts it after restore',
        (tester) async {
          final id = await boxes.createBoxWithGeneratedQrId();
          final qr = (await boxes.getBoxById(id))!.qrId;
          await archive(id);
          late Future<void> Function(String) scan;
          var stops = 0;
          var starts = 0;
          final Widget page = feeding
              ? FeedingScannerPage(
                  database: database,
                  onHandlerReady: (handler) => scan = handler,
                  stopScanner: () async {
                    stops++;
                  },
                  startScanner: () async {
                    starts++;
                  },
                )
              : BoxScannerPage(
                  database: database,
                  onHandlerReady: (handler) => scan = handler,
                  stopScanner: () async {
                    stops++;
                  },
                  startScanner: () async {
                    starts++;
                  },
                );
          await pumpPage(tester, page, language: language);
          await scan(qr);
          await tester.pumpAndSettle();
          expect(
            find.text(
              lookupAppLocalizations(Locale(language)).archivedBoxScanned,
            ),
            findsOneWidget,
          );
          expect(find.byType(BoxDetailPage), findsNothing);
          expect(find.byType(FeedingBoxAnimalsPage), findsNothing);
          expect(stops, 0);
          expect(starts, 0);
          expect(await database.select(database.feedingEvents).get(), isEmpty);
          await boxes.restoreBox(id);
          final opened = scan(qr);
          await tester.pumpAndSettle();
          expect(
            find.byType(feeding ? FeedingBoxAnimalsPage : BoxDetailPage),
            findsOneWidget,
          );
          expect(stops, 1);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          await opened;
          expect(starts, 1);
        },
      );
    }
  }
}
