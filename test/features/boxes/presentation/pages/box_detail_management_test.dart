import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/new_animal_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/features/navigation/domain/detail_navigation_context.dart';

const _transparentPixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+'
    'A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<Box> createTestBox({
    String qrId = 'TM:BOX:12345678-1234-4123-8123-123456789abc',
  }) async {
    final boxId = await BoxRepository(database).createBox(qrId);

    final box = await BoxRepository(database).getBoxById(boxId);

    return box!;
  }

  Future<int> createTestAnimal({
    required int boxId,
    String commonName = 'Corn Snake',
    String latinName = 'Pantherophis guttatus',
    int? pictureMediaId,
  }) {
    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: latinName,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      pictureMediaId: pictureMediaId,
    );
  }

  Future<int> createTestMedia({bool corrupt = false}) {
    return MediaRepository(database).createMedia(
      fileName: 'assigned-animal.png',
      mimeType: 'image/png',
      data: corrupt
          ? Uint8List.fromList([1, 2, 3])
          : base64Decode(_transparentPixelPng),
    );
  }

  Future<void> pumpDetailPage(WidgetTester tester, {required Box box}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoxDetailPage(database: database, box: box),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> scrollDown(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -500));

    await tester.pumpAndSettle();
  }

  Future<void> scrollToAddAnimal(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-animal-to-box-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillRequiredAnimalFields(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'New Snake',
    );
    await tester.enterText(
      find.byKey(const Key('latin-name-field')),
      'Pantherophis alleghaniensis',
    );
    await tester.enterText(find.byKey(const Key('temp-min-field')), '24');
    await tester.enterText(find.byKey(const Key('temp-max-field')), '28');
    await tester.enterText(find.byKey(const Key('humidity-min-field')), '40');
    await tester.enterText(find.byKey(const Key('humidity-max-field')), '60');
  }

  testWidgets('shows empty state when no animals are assigned', (tester) async {
    final box = await createTestBox();

    await pumpDetailPage(tester, box: box);

    await scrollDown(tester);

    expect(find.text('Assigned Animals'), findsOneWidget);

    expect(find.byKey(const Key('no-assigned-animals')), findsOneWidget);

    expect(find.text('No animals assigned to this box'), findsOneWidget);

    await scrollToAddAnimal(tester);

    expect(find.text('Add Animal'), findsOneWidget);
  });

  testWidgets('shows animals assigned to the box', (tester) async {
    final box = await createTestBox();

    await createTestAnimal(
      boxId: box.id,
      commonName: 'Corn Snake',
      latinName: 'Pantherophis guttatus',
    );

    await createTestAnimal(
      boxId: box.id,
      commonName: 'Rose Hair',
      latinName: 'Grammostola rosea',
    );

    await pumpDetailPage(tester, box: box);

    await scrollDown(tester);

    expect(find.text('Corn Snake'), findsOneWidget);

    expect(find.text('Pantherophis guttatus'), findsOneWidget);

    expect(find.text('Rose Hair'), findsOneWidget);

    expect(find.text('Grammostola rosea'), findsOneWidget);

    await scrollToAddAnimal(tester);

    expect(find.text('Add Animal'), findsOneWidget);
  });

  testWidgets('shows fallback thumbnail when assigned Animal has no picture', (
    tester,
  ) async {
    final box = await createTestBox();
    final animalId = await createTestAnimal(boxId: box.id);

    await pumpDetailPage(tester, box: box);

    final thumbnail = find.byKey(
      Key('assigned-animal-thumbnail-$animalId'),
    );
    await tester.scrollUntilVisible(
      thumbnail,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(thumbnail, findsOneWidget);
    expect(
      find.descendant(
        of: thumbnail,
        matching: find.byIcon(Icons.emoji_nature_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows picture thumbnail when assigned Animal has media', (
    tester,
  ) async {
    final box = await createTestBox();
    final mediaId = await createTestMedia();
    final animalId = await createTestAnimal(
      boxId: box.id,
      pictureMediaId: mediaId,
    );

    await pumpDetailPage(tester, box: box);

    final thumbnail = find.byKey(
      Key('assigned-animal-thumbnail-$animalId'),
    );
    await tester.scrollUntilVisible(
      thumbnail,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(thumbnail, findsOneWidget);
    expect(
      find.descendant(of: thumbnail, matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('falls back safely when assigned Animal media is invalid', (
    tester,
  ) async {
    final box = await createTestBox();
    final mediaId = await createTestMedia(corrupt: true);
    final animalId = await createTestAnimal(
      boxId: box.id,
      pictureMediaId: mediaId,
    );

    await pumpDetailPage(tester, box: box);

    final thumbnail = find.byKey(
      Key('assigned-animal-thumbnail-$animalId'),
    );
    await tester.scrollUntilVisible(
      thumbnail,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: thumbnail,
        matching: find.byIcon(Icons.emoji_nature_outlined),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a preassigned Animal from an empty Box', (tester) async {
    final box = await createTestBox();

    await pumpDetailPage(tester, box: box);
    await scrollToAddAnimal(tester);

    await tester.tap(find.byKey(const Key('add-animal-to-box-button')));
    await tester.pumpAndSettle();

    expect(find.byType(NewAnimalPage), findsOneWidget);

    final boxDropdown = tester.widget<DropdownButton<int>>(
      find.descendant(
        of: find.byKey(const Key('box-field')),
        matching: find.byType(DropdownButton<int>),
      ),
    );

    expect(boxDropdown.value, box.id);

    await fillRequiredAnimalFields(tester);
    await tester.tap(find.byKey(const Key('save-animal-button')));
    await tester.pumpAndSettle();

    expect(find.byType(NewAnimalPage), findsNothing);

    final animals = await AnimalRepository(database).getAnimalsForBox(box.id);

    expect(animals, hasLength(1));
    expect(animals.single.commonName, 'New Snake');

    await tester.scrollUntilVisible(
      find.text('New Snake'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('New Snake'), findsOneWidget);
  });

  testWidgets('cancelling direct Animal creation keeps the Box unchanged', (
    tester,
  ) async {
    final box = await createTestBox();

    await pumpDetailPage(tester, box: box);
    await scrollToAddAnimal(tester);

    await tester.tap(find.byKey(const Key('add-animal-to-box-button')));
    await tester.pumpAndSettle();

    expect(find.byType(NewAnimalPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(NewAnimalPage), findsNothing);
    expect(await AnimalRepository(database).getAnimalsForBox(box.id), isEmpty);

    await scrollToAddAnimal(tester);

    expect(find.byKey(const Key('add-animal-to-box-button')), findsOneWidget);
  });

  testWidgets('opens animal detail when assigned animal is tapped', (
    tester,
  ) async {
    final box = await createTestBox();

    final animalId = await createTestAnimal(boxId: box.id);

    await pumpDetailPage(tester, box: box);

    await scrollDown(tester);

    await tester.tap(find.byKey(Key('assigned-animal-$animalId')));

    await tester.pumpAndSettle();

    expect(find.byType(AnimalDetailPage), findsOneWidget);

    expect(find.text('Corn Snake'), findsOneWidget);
  });

  testWidgets('passes box-specific animal order to animal details', (
    tester,
  ) async {
    final box = await createTestBox();

    final firstId = await createTestAnimal(
      boxId: box.id,
      commonName: 'Animal One',
    );
    final secondId = await createTestAnimal(
      boxId: box.id,
      commonName: 'Animal Two',
    );
    final thirdId = await createTestAnimal(
      boxId: box.id,
      commonName: 'Animal Three',
    );

    await pumpDetailPage(tester, box: box);
    await scrollDown(tester);

    final target = find.byKey(Key('assigned-animal-$secondId'));

    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(target);
    await tester.pumpAndSettle();

    final detailPage = tester.widget<AnimalDetailPage>(
      find.byType(AnimalDetailPage),
    );
    final navigationContext = detailPage.navigationContext!;

    expect(navigationContext.source, DetailNavigationSource.boxAnimals);
    expect(navigationContext.sourceBoxId, box.id);
    expect(navigationContext.recordIds, [firstId, secondId, thirdId]);
    expect(navigationContext.currentRecordId, secondId);
    expect(navigationContext.currentIndex, 1);
  });

  testWidgets('shows delete confirmation for empty box', (tester) async {
    final box = await createTestBox();

    await pumpDetailPage(tester, box: box);

    await tester.tap(find.byKey(const Key('delete-box-button')));

    await tester.pumpAndSettle();

    expect(find.text('Delete Box?'), findsOneWidget);

    expect(find.byKey(const Key('cancel-delete-box-button')), findsOneWidget);

    expect(find.byKey(const Key('confirm-delete-box-button')), findsOneWidget);
  });

  testWidgets('does not delete box when deletion is cancelled', (tester) async {
    final box = await createTestBox();

    await pumpDetailPage(tester, box: box);

    await tester.tap(find.byKey(const Key('delete-box-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cancel-delete-box-button')));

    await tester.pumpAndSettle();

    final storedBox = await BoxRepository(database).getBoxById(box.id);

    expect(storedBox, isNotNull);
  });

  testWidgets('prevents deleting box with assigned animals', (tester) async {
    final box = await createTestBox();

    await createTestAnimal(boxId: box.id);

    await pumpDetailPage(tester, box: box);

    await tester.tap(find.byKey(const Key('delete-box-button')));

    await tester.pumpAndSettle();

    expect(find.text('Cannot Delete Box'), findsOneWidget);

    expect(
      find.text(
        '1 animal is assigned to this box.\n\n'
        'Move or delete the assigned animals before deleting the box.',
      ),
      findsOneWidget,
    );

    expect(find.byKey(const Key('confirm-delete-box-button')), findsNothing);

    final storedBox = await BoxRepository(database).getBoxById(box.id);

    expect(storedBox, isNotNull);
  });

  testWidgets('deletes empty box and refreshes box overview', (tester) async {
    final box = await createTestBox();

    await tester.pumpWidget(MaterialApp(home: BoxesPage(database: database)));

    await tester.pumpAndSettle();

    expect(find.text('Box 1'), findsOneWidget);

    await tester.tap(find.byKey(Key('box-list-item-${box.id}')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('box-detail-title')), findsOneWidget);

    expect(find.text('Box 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-box-button')));

    await tester.pumpAndSettle();

    expect(find.text('Delete Box?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-delete-box-button')));

    await tester.pumpAndSettle();

    final storedBox = await BoxRepository(database).getBoxById(box.id);

    expect(storedBox, isNull);

    expect(find.text('No boxes available'), findsOneWidget);

    expect(find.text(box.qrId), findsNothing);
  });
}
