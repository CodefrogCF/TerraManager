import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_history_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_history_page.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository animals;
  late BoxRepository boxes;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    animals = AnimalRepository(database);
    boxes = BoxRepository(database);
  });

  tearDown(() => database.close());

  Future<int> createAnimal(int boxId, String name, {int? pictureMediaId}) {
    return animals.createAnimal(
      boxId: boxId,
      commonName: name,
      latinName: 'Test species',
      tempMin: 22,
      tempMax: 30,
      humidityMin: 40,
      humidityMax: 70,
      pictureMediaId: pictureMediaId,
    );
  }

  Future<void> pumpAnimals(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimalsPage(database: database),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpBoxes(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BoxesPage(database: database),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> pumpBoxHistory(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BoxHistoryPage(database: database),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> dismissMenu(WidgetTester tester) async {
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
  }

  testWidgets('Animal long-press and right-click open the same labeled menu', (
    tester,
  ) async {
    final boxId = await boxes.createBox('box-1');
    final animalId = await createAnimal(boxId, 'Target Animal');
    await pumpAnimals(tester);

    expect(find.byTooltip('Actions for Target Animal'), findsOneWidget);
    final tile = find.byKey(Key('animal-list-item-$animalId'));

    await tester.longPress(tile);
    await tester.pumpAndSettle();
    expect(find.text('Create Feeding'), findsOneWidget);
    expect(find.text('Rename Animal'), findsOneWidget);
    expect(find.text('Edit Animal'), findsOneWidget);
    expect(find.text('Archive Animal'), findsOneWidget);
    expect(find.text('Duplicate Animal'), findsOneWidget);

    await dismissMenu(tester);
    await tester.tap(
      tile,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('Create Feeding'), findsOneWidget);
    expect(find.text('Duplicate Animal'), findsOneWidget);
  });

  testWidgets('German Animal and Box menus show every localized action', (
    tester,
  ) async {
    final boxId = await boxes.createBox('box-1', name: 'Hauptbox');
    final animalId = await createAnimal(boxId, 'Zieltier');

    await pumpAnimals(tester, locale: const Locale('de'));
    await tester.tap(find.byKey(Key('animal-context-menu-button-$animalId')));
    await tester.pumpAndSettle();
    expect(find.text('Fütterung erstellen'), findsOneWidget);
    expect(find.text('Tier umbenennen'), findsOneWidget);
    expect(find.text('Tier bearbeiten'), findsOneWidget);
    expect(find.text('Tier archivieren'), findsOneWidget);
    expect(find.text('Tier duplizieren'), findsOneWidget);
    await dismissMenu(tester);

    await pumpBoxes(tester, locale: const Locale('de'));
    await tester.tap(find.byKey(Key('box-context-menu-button-$boxId')));
    await tester.pumpAndSettle();
    expect(find.text('Box umbenennen'), findsOneWidget);
    expect(find.text('Box bearbeiten'), findsOneWidget);
    expect(find.text('Box duplizieren'), findsOneWidget);
    expect(find.text('Box archivieren'), findsOneWidget);
  });

  testWidgets('Animal rename can cancel and targets the selected row', (
    tester,
  ) async {
    final boxId = await boxes.createBox('box-1');
    final firstId = await createAnimal(boxId, 'First Animal');
    final targetId = await createAnimal(boxId, 'Target Animal');
    await pumpAnimals(tester);

    await tester.tap(find.byKey(Key('animal-context-menu-button-$targetId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename Animal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('rename-animal-name-field')),
      'Cancelled Name',
    );
    await tester.tap(find.byKey(const Key('cancel-rename-animal-button')));
    await tester.pumpAndSettle();
    expect(
      (await animals.getAnimalById(targetId))!.commonName,
      'Target Animal',
    );

    await tester.tap(find.byKey(Key('animal-context-menu-button-$targetId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename Animal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('rename-animal-name-field')),
      'Renamed Target',
    );
    await tester.tap(find.byKey(const Key('save-rename-animal-button')));
    await tester.pumpAndSettle();

    expect((await animals.getAnimalById(firstId))!.commonName, 'First Animal');
    expect(
      (await animals.getAnimalById(targetId))!.commonName,
      'Renamed Target',
    );
    expect(find.text('Renamed Target'), findsOneWidget);
  });

  testWidgets('Animal quick actions create feeding and use existing flows', (
    tester,
  ) async {
    final boxId = await boxes.createBox('box-1');
    final animalId = await createAnimal(boxId, 'Target Animal');
    await pumpAnimals(tester);

    await tester.tap(find.byKey(Key('animal-context-menu-button-$animalId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Feeding'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feeding-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-feeding-button')));
    await tester.pumpAndSettle();
    expect(
      await FeedingRepository(database).getFeedingsForAnimal(animalId),
      hasLength(1),
    );

    await tester.tap(find.byKey(Key('animal-context-menu-button-$animalId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Animal'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Animal'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('animal-context-menu-button-$animalId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive Animal'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-animal-dialog')), findsOneWidget);
  });

  testWidgets(
    'Animal duplicate can cancel and appears immediately when saved',
    (tester) async {
      final boxId = await boxes.createBox('box-1', name: 'Home');
      final media = MediaRepository(database);
      final pictureId = await media.createMedia(
        fileName: 'animal.webp',
        mimeType: 'image/webp',
        data: Uint8List.fromList([1, 2, 3]),
      );
      final animalId = await createAnimal(
        boxId,
        'Source Animal',
        pictureMediaId: pictureId,
      );
      await pumpAnimals(tester);

      await tester.tap(find.byKey(Key('animal-context-menu-button-$animalId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate Animal'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('duplicate-animal-dialog')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('duplicate-animal-name-field')),
            )
            .controller!
            .text,
        'Source Animal (copy)',
      );
      await tester.tap(find.byKey(const Key('cancel-duplicate-animal-button')));
      await tester.pumpAndSettle();
      expect(await animals.getAllAnimals(), hasLength(1));
      expect(await database.select(database.mediaAssets).get(), hasLength(1));

      await tester.tap(find.byKey(Key('animal-context-menu-button-$animalId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate Animal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('duplicate-animal-name-field')),
        'Independent Copy',
      );
      await tester.tap(find.byKey(const Key('save-duplicate-animal-button')));
      await tester.pumpAndSettle();
      expect(await animals.getAllAnimals(), hasLength(2));
      expect(await database.select(database.mediaAssets).get(), hasLength(2));
      expect(find.text('Independent Copy'), findsOneWidget);
    },
  );

  testWidgets(
    'Box context menu supports both gestures and selected-row rename',
    (tester) async {
      final firstId = await boxes.createBox('box-1', name: 'First Box');
      final targetId = await boxes.createBox('box-2', name: 'Target Box');
      await pumpBoxes(tester);

      expect(find.byTooltip('Actions for Target Box'), findsOneWidget);
      final targetTile = find.byKey(Key('box-list-item-$targetId'));
      await tester.longPress(targetTile);
      await tester.pumpAndSettle();
      expect(find.text('Rename Box'), findsOneWidget);
      expect(find.text('Edit Box'), findsOneWidget);
      expect(find.text('Duplicate Box'), findsOneWidget);
      expect(find.text('Archive Box'), findsOneWidget);
      await dismissMenu(tester);

      await tester.tap(
        targetTile,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename Box'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('rename-box-name-field')),
        'Renamed Box',
      );
      await tester.tap(find.byKey(const Key('save-rename-box-button')));
      await tester.pumpAndSettle();

      expect((await boxes.getBoxById(firstId))!.name, 'First Box');
      expect((await boxes.getBoxById(targetId))!.name, 'Renamed Box');
      expect(find.text('Renamed Box'), findsOneWidget);
    },
  );

  testWidgets('Box duplicate cancel is inert and save refreshes the overview', (
    tester,
  ) async {
    final pictureId = await MediaRepository(database).createMedia(
      fileName: 'box.webp',
      mimeType: 'image/webp',
      data: Uint8List.fromList([4, 5, 6]),
    );
    final boxId = await boxes.createBox(
      'box-1',
      name: 'Source Box',
      pictureMediaId: pictureId,
    );
    await pumpBoxes(tester);

    await tester.tap(find.byKey(Key('box-context-menu-button-$boxId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate Box'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-duplicate-box-button')));
    await tester.pumpAndSettle();
    expect(await boxes.getAllBoxes(), hasLength(1));
    expect(await database.select(database.mediaAssets).get(), hasLength(1));

    await tester.tap(find.byKey(Key('box-context-menu-button-$boxId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate Box'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('duplicate-box-name-field')),
      'Independent Box',
    );
    await tester.tap(find.byKey(const Key('save-duplicate-box-button')));
    await tester.pumpAndSettle();
    expect(await boxes.getAllBoxes(), hasLength(2));
    expect(await database.select(database.mediaAssets).get(), hasLength(2));
    expect(find.text('Independent Box'), findsOneWidget);
  });

  testWidgets('Box edit and archive actions reuse existing workflows', (
    tester,
  ) async {
    final boxId = await boxes.createBox('box-1', name: 'Source Box');
    await pumpBoxes(tester);

    await tester.tap(find.byKey(Key('box-context-menu-button-$boxId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Box'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Box 1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('box-context-menu-button-$boxId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive Box'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-box-dialog')), findsOneWidget);
  });

  testWidgets('archived overviews expose only the valid duplicate action', (
    tester,
  ) async {
    final boxId = await boxes.createBox('box-1');
    final animalId = await createAnimal(boxId, 'Archived Animal');
    await animals.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 14),
    );
    await boxes.archiveBox(
      boxId: boxId,
      reason: BoxArchiveReason.replaced,
      archivedAt: DateTime(2026, 9, 14),
    );

    await pumpBoxHistory(tester);
    await tester.tap(
      find.byKey(Key('archived-box-context-menu-button-$boxId')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Duplicate Box'), findsOneWidget);
    expect(find.text('Rename Box'), findsNothing);
    expect(find.text('Edit Box'), findsNothing);
    expect(find.text('Archive Box'), findsNothing);
    await dismissMenu(tester);

    await tester.pumpWidget(
      MaterialApp(home: AnimalHistoryPage(database: database)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('archived-animal-context-menu-button-$animalId')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Duplicate Animal'), findsOneWidget);
    expect(find.text('Create Feeding'), findsNothing);
    expect(find.text('Rename Animal'), findsNothing);
    expect(find.text('Edit Animal'), findsNothing);
    expect(find.text('Archive Animal'), findsNothing);
  });
}
