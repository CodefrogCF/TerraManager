import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_history_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';
import 'package:terramanager/features/navigation/domain/detail_navigation_context.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/archive_sort_order.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository animalRepository;
  late BoxRepository boxRepository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    database = AppDatabase.test(NativeDatabase.memory());

    animalRepository = AnimalRepository(database);

    boxRepository = BoxRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createBox(String qrId) {
    return boxRepository.createBox(qrId);
  }

  Future<int> createAnimal({
    required int boxId,
    required String commonName,
    int? pictureMediaId,
    String? picturePath,
  }) {
    return animalRepository.createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      pictureMediaId: pictureMediaId,
      picturePath: picturePath,
    );
  }

  Future<int> createPicture() {
    return MediaRepository(database).createMedia(
      fileName: 'archived-animal.png',
      mimeType: 'image/png',
      data: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4'
        '2mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  }

  Future<void> scrollToKey(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();
  }

  Future<AppSettingsController> pumpHistoryWithSettings(
    WidgetTester tester,
  ) async {
    final settings = AppSettingsController();

    await settings.load();

    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(home: AnimalHistoryPage(database: database)),
      ),
    );

    await tester.pumpAndSettle();

    return settings;
  }

  testWidgets('animal overview opens empty history', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AnimalsPage(database: database)));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('animal-history-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('animal-history-button')));

    await tester.pumpAndSettle();

    expect(find.text('Animal History'), findsOneWidget);

    expect(find.byKey(const Key('animal-history-empty-state')), findsOneWidget);

    expect(find.text('No archived animals'), findsOneWidget);
  });

  testWidgets('history displays archived animal metadata', (tester) async {
    final boxId = await createBox(
      'TM:BOX:11111111-aaaa-4111-8111-111111111111',
    );

    final animalId = await createAnimal(
      boxId: boxId,
      commonName: 'Archived Snake',
    );

    await animalRepository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.sold,
      archivedAt: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      MaterialApp(home: AnimalHistoryPage(database: database)),
    );

    await tester.pumpAndSettle();

    expect(find.text('Archived Snake'), findsOneWidget);

    expect(find.text('Pantherophis guttatus'), findsOneWidget);

    expect(find.text('Sold • 01.09.2026'), findsOneWidget);

    expect(
      find.byKey(Key('archived-animal-list-item-$animalId')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(Key('archived-animal-list-item-$animalId')));

    await tester.pumpAndSettle();

    await scrollToKey(tester, const Key('restore-animal-button'));

    expect(
      find.byKey(const Key('archive-information-heading')),
      findsOneWidget,
    );
  });

  testWidgets('history displays stored thumbnails and opens them', (
    tester,
  ) async {
    final boxId = await createBox(
      'TM:BOX:10101010-aaaa-4101-8101-101010101010',
    );
    final pictureMediaId = await createPicture();
    final animalId = await createAnimal(
      boxId: boxId,
      commonName: 'Pictured Animal',
      pictureMediaId: pictureMediaId,
    );
    await animalRepository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      MaterialApp(home: AnimalHistoryPage(database: database)),
    );
    await tester.pumpAndSettle();

    final thumbnail = find.byKey(Key('archived-animal-thumbnail-$animalId'));
    expect(thumbnail, findsOneWidget);
    expect(
      find.descendant(of: thumbnail, matching: find.byType(Image)),
      findsOneWidget,
    );
    final thumbnailSemantics = tester.widget<Semantics>(
      find.descendant(of: thumbnail, matching: find.byType(Semantics)).first,
    );
    expect(
      thumbnailSemantics.properties.label,
      'Animal thumbnail for Pictured Animal',
    );

    await tester.tap(thumbnail);
    await tester.pumpAndSettle();

    expect(find.byType(AnimalDetailPage), findsOneWidget);
    expect(find.text('Pictured Animal'), findsOneWidget);
  });

  testWidgets('history uses the fallback for missing or invalid media', (
    tester,
  ) async {
    final boxId = await createBox(
      'TM:BOX:20202020-aaaa-4202-8202-202020202020',
    );
    final animalId = await createAnimal(
      boxId: boxId,
      commonName: 'Missing Picture',
      picturePath: 'missing/archived-animal.png',
    );
    await animalRepository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      MaterialApp(home: AnimalHistoryPage(database: database)),
    );
    await tester.pumpAndSettle();

    final thumbnail = find.byKey(Key('archived-animal-thumbnail-$animalId'));
    expect(
      find.descendant(
        of: thumbnail,
        matching: find.byIcon(Icons.emoji_nature_outlined),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('passes archived history order to animal details', (
    tester,
  ) async {
    final boxId = await createBox(
      'TM:BOX:12121212-aaaa-4121-8121-121212121212',
    );

    final oldestId = await createAnimal(
      boxId: boxId,
      commonName: 'Oldest Animal',
    );
    final middleId = await createAnimal(
      boxId: boxId,
      commonName: 'Middle Animal',
    );
    final newestId = await createAnimal(
      boxId: boxId,
      commonName: 'Newest Animal',
    );

    await animalRepository.archiveAnimal(
      animalId: oldestId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );
    await animalRepository.archiveAnimal(
      animalId: middleId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 2),
    );
    await animalRepository.archiveAnimal(
      animalId: newestId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 3),
    );

    await tester.pumpWidget(
      MaterialApp(home: AnimalHistoryPage(database: database)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('archived-animal-list-item-$middleId')));
    await tester.pumpAndSettle();

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );
    final navigationContext = detailPage.navigationContext!;

    expect(navigationContext.source, DetailNavigationSource.archivedAnimals);
    expect(navigationContext.recordIds, [newestId, middleId, oldestId]);
    expect(navigationContext.currentRecordId, middleId);
    expect(navigationContext.currentIndex, 1);
  });

  testWidgets('restored animal leaves history and returns to active overview', (
    tester,
  ) async {
    final firstBoxId = await createBox(
      'TM:BOX:22222222-aaaa-4222-8222-222222222222',
    );

    final secondBoxId = await createBox(
      'TM:BOX:33333333-aaaa-4333-8333-333333333333',
    );

    final animalId = await createAnimal(
      boxId: firstBoxId,
      commonName: 'Restore Me',
    );

    await animalRepository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.rehomed,
      archivedAt: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(MaterialApp(home: AnimalsPage(database: database)));

    await tester.pumpAndSettle();

    expect(find.text('Restore Me'), findsNothing);

    await tester.tap(find.byKey(const Key('animal-history-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('archived-animal-list-item-$animalId')));

    await tester.pumpAndSettle();

    await scrollToKey(tester, const Key('restore-animal-button'));

    await tester.tap(find.byKey(const Key('restore-animal-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('restore-box-field')));

    await tester.pumpAndSettle();

    expect(find.text('Box $firstBoxId'), findsOneWidget);
    expect(find.text('Box $secondBoxId'), findsOneWidget);

    expect(
      find.text('TM:BOX:22222222-aaaa-4222-8222-222222222222'),
      findsNothing,
    );

    expect(
      find.text('TM:BOX:33333333-aaaa-4333-8333-333333333333'),
      findsNothing,
    );

    await tester.tap(find.text('Box $secondBoxId').last);

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-restore-animal-button')));

    await tester.pumpAndSettle();

    final animal = await animalRepository.getAnimalById(animalId);

    expect(animal!.boxId, secondBoxId);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Restore Me'), findsNothing);

    expect(find.text('No archived animals'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Restore Me'), findsOneWidget);
  });

  testWidgets('archived animal can be permanently deleted from history', (
    tester,
  ) async {
    final boxId = await createBox(
      'TM:BOX:44444444-aaaa-4444-8444-444444444444',
    );

    final animalId = await createAnimal(boxId: boxId, commonName: 'Delete Me');

    await animalRepository.archiveAnimal(
      animalId: animalId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      MaterialApp(home: AnimalHistoryPage(database: database)),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('archived-animal-list-item-$animalId')));

    await tester.pumpAndSettle();

    await scrollToKey(tester, const Key('permanent-delete-animal-button'));

    await tester.tap(find.byKey(const Key('permanent-delete-animal-button')));

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('permanent-delete-animal-dialog')),
      findsOneWidget,
    );

    expect(
      find.textContaining('all associated feeding history'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('confirm-permanent-delete-animal-button')),
    );

    await tester.pumpAndSettle();

    expect(await animalRepository.getAnimalById(animalId), isNull);

    expect(find.text('Delete Me'), findsNothing);

    expect(find.text('No archived animals'), findsOneWidget);
  });

  testWidgets('sorts archived animals alphabetically '
      'ascending and descending', (tester) async {
    final boxId = await createBox(
      'TM:BOX:56565656-aaaa-4565-8565-565656565656',
    );

    final tenId = await createAnimal(boxId: boxId, commonName: 'Animal 10');

    final twoId = await createAnimal(boxId: boxId, commonName: 'Animal 2');

    final oneId = await createAnimal(boxId: boxId, commonName: 'Animal 1');

    await animalRepository.archiveAnimal(
      animalId: tenId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );

    await animalRepository.archiveAnimal(
      animalId: twoId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 2),
    );

    await animalRepository.archiveAnimal(
      animalId: oneId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 3),
    );

    final settings = await pumpHistoryWithSettings(tester);

    expect(
      settings.animalArchiveSortOrder,
      ArchiveSortOrder.archivedNewestFirst,
    );

    await tester.tap(find.byKey(const Key('animal-archive-sort-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('animal-archive-sort-option-name')));

    await tester.pumpAndSettle();

    expect(settings.animalArchiveSortOrder, ArchiveSortOrder.nameAscending);

    expect(
      tester
          .getTopLeft(
            find.byKey(
              Key(
                'archived-animal-list-item-'
                '$oneId',
              ),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                Key(
                  'archived-animal-list-item-'
                  '$twoId',
                ),
              ),
            )
            .dy,
      ),
    );

    expect(
      tester
          .getTopLeft(
            find.byKey(
              Key(
                'archived-animal-list-item-'
                '$twoId',
              ),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                Key(
                  'archived-animal-list-item-'
                  '$tenId',
                ),
              ),
            )
            .dy,
      ),
    );

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('animal_archive_sort_order'), 'nameAscending');

    await tester.tap(find.byKey(const Key('animal-archive-sort-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('animal-archive-sort-option-name')));

    await tester.pumpAndSettle();

    expect(settings.animalArchiveSortOrder, ArchiveSortOrder.nameDescending);

    expect(
      tester
          .getTopLeft(
            find.byKey(
              Key(
                'archived-animal-list-item-'
                '$tenId',
              ),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                Key(
                  'archived-animal-list-item-'
                  '$twoId',
                ),
              ),
            )
            .dy,
      ),
    );

    settings.dispose();
  });
}
