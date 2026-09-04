import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';
import 'package:terramanager/features/navigation/domain/detail_navigation_context.dart';

void main() {
  late AppDatabase database;
  late AnimalRepository animalRepository;
  late BoxRepository boxRepository;
  late FeedingRepository feedingRepository;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    animalRepository = AnimalRepository(database);
    boxRepository = BoxRepository(database);
    feedingRepository = FeedingRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createBox(String qrId) {
    return boxRepository.createBox(qrId);
  }

  Future<int> createAnimal({required int boxId, required String commonName}) {
    return animalRepository.createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required int animalId,
    required DetailNavigationContext navigationContext,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(
          database: database,
          animalId: animalId,
          navigationContext: navigationContext,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> swipeLeft(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('animal-detail-swipe-area')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeRight(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('animal-detail-swipe-area')),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToKey(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('swipes through active animals in source order', (tester) async {
    final boxId = await createBox('active-swipe-box');
    final firstId = await createAnimal(boxId: boxId, commonName: 'Animal One');
    final secondId = await createAnimal(boxId: boxId, commonName: 'Animal Two');
    final thirdId = await createAnimal(
      boxId: boxId,
      commonName: 'Animal Three',
    );

    await pumpDetail(
      tester,
      animalId: secondId,
      navigationContext: DetailNavigationContext.activeAnimals(
        animalIds: [firstId, secondId, thirdId],
        currentAnimalId: secondId,
      ),
    );

    expect(find.text('Animal Two'), findsOneWidget);

    await swipeLeft(tester);
    expect(find.text('Animal Three'), findsOneWidget);

    await swipeLeft(tester);
    expect(find.text('Animal Three'), findsOneWidget);

    await swipeRight(tester);
    expect(find.text('Animal Two'), findsOneWidget);

    await swipeRight(tester);
    expect(find.text('Animal One'), findsOneWidget);

    await swipeRight(tester);
    expect(find.text('Animal One'), findsOneWidget);
  });

  testWidgets('swipes only through archived animals', (tester) async {
    final boxId = await createBox('archived-swipe-box');
    final firstId = await createAnimal(
      boxId: boxId,
      commonName: 'Archived One',
    );
    final secondId = await createAnimal(
      boxId: boxId,
      commonName: 'Archived Two',
    );

    await animalRepository.archiveAnimal(
      animalId: firstId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );
    await animalRepository.archiveAnimal(
      animalId: secondId,
      reason: AnimalArchiveReason.other,
      archivedAt: DateTime(2026, 9, 2),
    );

    await pumpDetail(
      tester,
      animalId: firstId,
      navigationContext: DetailNavigationContext.archivedAnimals(
        animalIds: [firstId, secondId],
        currentAnimalId: firstId,
      ),
    );

    expect(find.text('Archived One'), findsOneWidget);

    await swipeLeft(tester);

    expect(find.text('Archived Two'), findsOneWidget);
    expect(find.byKey(const Key('edit-animal-button')), findsNothing);
  });

  testWidgets('box context excludes animals from other boxes', (tester) async {
    final sourceBoxId = await createBox('source-swipe-box');
    final otherBoxId = await createBox('other-swipe-box');
    final firstId = await createAnimal(
      boxId: sourceBoxId,
      commonName: 'Box Animal One',
    );
    final secondId = await createAnimal(
      boxId: sourceBoxId,
      commonName: 'Box Animal Two',
    );
    await createAnimal(boxId: otherBoxId, commonName: 'Other Box Animal');

    await pumpDetail(
      tester,
      animalId: firstId,
      navigationContext: DetailNavigationContext.animalsForBox(
        animalIds: [firstId, secondId],
        currentAnimalId: firstId,
        boxId: sourceBoxId,
      ),
    );

    await swipeLeft(tester);

    expect(find.text('Box Animal Two'), findsOneWidget);
    expect(find.text('Other Box Animal'), findsNothing);

    await swipeLeft(tester);

    expect(find.text('Box Animal Two'), findsOneWidget);
    expect(find.text('Other Box Animal'), findsNothing);
  });

  testWidgets('feeding history and edit use the swiped animal', (tester) async {
    final boxId = await createBox('action-swipe-box');
    final firstId = await createAnimal(boxId: boxId, commonName: 'Animal One');
    final secondId = await createAnimal(boxId: boxId, commonName: 'Animal Two');

    await feedingRepository.addFeeding(
      firstId,
      DateTime(2026, 9, 1, 12),
      notes: 'First animal feeding',
    );
    await feedingRepository.addFeeding(
      secondId,
      DateTime(2026, 9, 2, 12),
      notes: 'Second animal feeding',
    );

    await pumpDetail(
      tester,
      animalId: firstId,
      navigationContext: DetailNavigationContext.activeAnimals(
        animalIds: [firstId, secondId],
        currentAnimalId: firstId,
      ),
    );

    await swipeLeft(tester);

    await tester.tap(find.byKey(const Key('feeding-history-button')));
    await tester.pumpAndSettle();

    expect(find.text('Second animal feeding'), findsOneWidget);
    expect(find.text('First animal feeding'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-animal-button')));
    await tester.pumpAndSettle();

    final commonNameField = tester.widget<TextFormField>(
      find.byKey(const Key('common-name-field')),
    );

    expect(commonNameField.controller!.text, 'Animal Two');
  });

  testWidgets('archiving clears an invalid active swipe context', (
    tester,
  ) async {
    final boxId = await createBox('lifecycle-swipe-box');
    final firstId = await createAnimal(boxId: boxId, commonName: 'Archive Me');
    final secondId = await createAnimal(
      boxId: boxId,
      commonName: 'Stay Active',
    );

    await pumpDetail(
      tester,
      animalId: firstId,
      navigationContext: DetailNavigationContext.activeAnimals(
        animalIds: [firstId, secondId],
        currentAnimalId: firstId,
      ),
    );

    await scrollToKey(tester, const Key('archive-animal-button'));
    await tester.tap(find.byKey(const Key('archive-animal-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('archive-reason-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-archive-animal-button')));
    await tester.pumpAndSettle();

    await scrollToKey(tester, const Key('archive-information-heading'));
    await swipeLeft(tester);

    expect(
      find.byKey(const Key('archive-information-heading')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('edit-animal-button')), findsNothing);
    expect(find.text('Stay Active'), findsNothing);
  });

  testWidgets('back returns to the original animal overview', (tester) async {
    final boxId = await createBox('back-navigation-box');
    await createAnimal(boxId: boxId, commonName: 'Animal One');
    final secondId = await createAnimal(boxId: boxId, commonName: 'Animal Two');
    await createAnimal(boxId: boxId, commonName: 'Animal Three');

    await tester.pumpWidget(MaterialApp(home: AnimalsPage(database: database)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('animal-list-item-$secondId')));
    await tester.pumpAndSettle();

    await swipeLeft(tester);

    expect(find.text('Animal Three'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Animals'), findsOneWidget);
    expect(find.text('Animal Details'), findsNothing);
    expect(find.text('Animal One'), findsOneWidget);
    expect(find.text('Animal Two'), findsOneWidget);
    expect(find.text('Animal Three'), findsOneWidget);
  });
}
