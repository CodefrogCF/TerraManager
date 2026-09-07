import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_edit_page.dart';
import 'package:terramanager/features/media/presentation/picture_selection_flow.dart';
import 'package:terramanager/features/media/presentation/widgets/picture_selection_controls.dart';

import '../../../media/presentation/fake_picture_selection_flow.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createTestAnimal({int? pictureMediaId}) async {
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-001'));

    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Test Snake',
      latinName: 'Pantherophis guttatus',
      sex: Sex.female,
      birthDate: DateTime(2024, 5, 10),
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      pictureMediaId: pictureMediaId,
      notes: 'Original notes',
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required int animalId,
    PictureSelectionFlow? pictureSelectionFlow,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnimalEditPage(
          database: database,
          animalId: animalId,
          pictureSelectionFlow: pictureSelectionFlow,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> pumpPageWithNavigation(
    WidgetTester tester, {
    required int animalId,
    PictureSelectionFlow? pictureSelectionFlow,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-edit-page-button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AnimalEditPage(
                          database: database,
                          animalId: animalId,
                          pictureSelectionFlow: pictureSelectionFlow,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Edit'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-edit-page-button')));

    await tester.pumpAndSettle();
  }

  testWidgets('shows loading indicator while loading animal', (tester) async {
    final animalId = await createTestAnimal();

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalEditPage(database: database, animalId: animalId),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Edit Animal'), findsOneWidget);
  });

  testWidgets('loads existing animal data into form', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('common-name-field')))
          .controller!
          .text,
      'Test Snake',
    );

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('latin-name-field')))
          .controller!
          .text,
      'Pantherophis guttatus',
    );

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('temp-min-field')))
          .controller!
          .text,
      '24.0',
    );

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('temp-max-field')))
          .controller!
          .text,
      '28.0',
    );

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('humidity-min-field')))
          .controller!
          .text,
      '40.0',
    );

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('humidity-max-field')))
          .controller!
          .text,
      '60.0',
    );

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('notes-field')))
          .controller!
          .text,
      'Original notes',
    );

    expect(find.byKey(const Key('sex-field')), findsOneWidget);

    expect(find.text('Sex.female'), findsOneWidget);

    expect(find.byKey(const Key('birth-date-field')), findsOneWidget);

    expect(find.text('10.05.2024'), findsOneWidget);

    expect(find.byKey(const Key('box-field')), findsOneWidget);

    expect(find.text('Box 1'), findsOneWidget);
  });

  testWidgets('shows error when animal does not exist', (tester) async {
    await pumpPage(tester, animalId: 999);

    expect(find.text('Animal not found'), findsOneWidget);
  });

  testWidgets('saves changed animal data', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'Updated Snake',
    );

    await tester.pump();

    await tester.tap(find.byTooltip('Save'));

    await tester.pumpAndSettle();

    final updatedAnimal = await AnimalRepository(database)
        .getAnimalById(animalId);

    expect(updatedAnimal, isNotNull);

    expect(updatedAnimal!.commonName, 'Updated Snake');
  });

  testWidgets('can change associated box', (tester) async {
    final animalId = await createTestAnimal();

    final secondBoxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'test-box-002'));

    await pumpPage(tester, animalId: animalId);

    await tester.tap(find.byKey(const Key('box-field')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Box 2').last);

    expect(find.text('test-box-001'), findsNothing);

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save'));

    await tester.pumpAndSettle();

    final updatedAnimal = await AnimalRepository(database)
        .getAnimalById(animalId);

    expect(updatedAnimal, isNotNull);

    expect(updatedAnimal!.boxId, secondBoxId);
  });

  testWidgets('validates required common name', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    await tester.enterText(find.byKey(const Key('common-name-field')), '');

    await tester.tap(find.byTooltip('Save'));

    await tester.pumpAndSettle();

    expect(find.text('Please enter a common name'), findsOneWidget);

    final unchangedAnimal = await AnimalRepository(database)
        .getAnimalById(animalId);

    expect(unchangedAnimal!.commonName, 'Test Snake');
  });

  testWidgets('validates required latin name', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    await tester.enterText(find.byKey(const Key('latin-name-field')), '');

    await tester.tap(find.byTooltip('Save'));

    await tester.pumpAndSettle();

    expect(find.text('Please enter a latin name'), findsOneWidget);
  });

  testWidgets('validates numeric fields', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    await tester.enterText(
      find.byKey(const Key('temp-min-field')),
      'not-a-number',
    );

    await tester.tap(find.byTooltip('Save'));

    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid number'), findsOneWidget);
  });

  testWidgets('shows unsaved changes dialog when leaving', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPageWithNavigation(tester, animalId: animalId);

    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'Changed Snake',
    );

    await tester.pump();

    await tester.tap(find.byKey(const Key('back-button')));

    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsOneWidget);

    expect(
      find.text('You have unsaved changes. Do you really want to leave?'),
      findsOneWidget,
    );

    expect(find.text('Cancel'), findsOneWidget);

    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('cancel keeps edit page open', (tester) async {
    final animalId = await createTestAnimal();

    await pumpPageWithNavigation(tester, animalId: animalId);

    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'Changed Snake',
    );

    await tester.pump();

    await tester.tap(find.byKey(const Key('back-button')));

    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Cancel'));

    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsNothing);

    expect(find.text('Edit Animal'), findsOneWidget);

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('common-name-field')),
    );

    expect(field.controller!.text, 'Changed Snake');
  });

  testWidgets('discard leaves edit page without saving changes', (
    tester,
  ) async {
    final animalId = await createTestAnimal();

    await pumpPageWithNavigation(tester, animalId: animalId);

    await tester.enterText(
      find.byKey(const Key('common-name-field')),
      'Changed Snake',
    );

    await tester.pump();

    await tester.tap(find.byKey(const Key('back-button')));

    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Discard'));

    await tester.pumpAndSettle();

    expect(find.text('Edit Animal'), findsNothing);

    expect(find.text('Open Edit'), findsOneWidget);

    final animal = await AnimalRepository(database).getAnimalById(animalId);

    expect(animal, isNotNull);

    expect(animal!.commonName, 'Test Snake');
  });

  testWidgets('leaves without confirmation when nothing changed', (
    tester,
  ) async {
    final animalId = await createTestAnimal();

    await pumpPageWithNavigation(tester, animalId: animalId);

    await tester.tap(find.byKey(const Key('back-button')));

    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsNothing);

    expect(find.text('Open Edit'), findsOneWidget);
  });

  testWidgets('shows one Add Picture action without an existing picture', (
    tester,
  ) async {
    final animalId = await createTestAnimal();

    await pumpPage(tester, animalId: animalId);

    expect(find.byKey(const Key('select-picture-button')), findsOneWidget);

    expect(find.text('Add Picture'), findsOneWidget);

    expect(find.byKey(const Key('remove-picture-button')), findsNothing);
  });

  testWidgets('shows Change Picture and delete for an existing picture', (
    tester,
  ) async {
    final mediaId = await MediaRepository(database).createMedia(
      fileName: 'animal.png',
      mimeType: 'image/png',
      data: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    final animalId = await createTestAnimal(pictureMediaId: mediaId);

    await pumpPage(tester, animalId: animalId);

    expect(find.byKey(const Key('select-picture-button')), findsOneWidget);
    expect(find.text('Change Picture'), findsOneWidget);
    expect(find.byKey(const Key('remove-picture-button')), findsOneWidget);

    expect(find.text('Take Photo'), findsNothing);
    expect(find.text('Choose from Gallery'), findsNothing);

    await tester.tap(find.byKey(const Key('select-picture-button')));
    await tester.pumpAndSettle();

    expect(find.text('Choose Picture Source'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });

  testWidgets('atomically stores one normalized Animal replacement', (
    tester,
  ) async {
    final existingBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final oldMediaId = await MediaRepository(database).createMedia(
      fileName: 'existing-animal.png',
      mimeType: 'image/png',
      data: existingBytes,
    );
    final selection = Completer<SelectedPicture?>();
    final flow = FakePictureSelectionFlow(pendingResult: selection.future);
    final animalId = await createTestAnimal(pictureMediaId: oldMediaId);

    await pumpPage(tester, animalId: animalId, pictureSelectionFlow: flow);

    await tester.tap(find.byKey(const Key('select-picture-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictureSelectionControls.galleryOptionKey));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(
      find.byKey(PictureSelectionControls.processingIndicatorKey),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('save-animal-button')))
          .onPressed,
      isNull,
    );
    expect(await MediaRepository(database).getMediaById(oldMediaId), isNotNull);

    selection.complete(normalizedTestPicture('edited-animal.webp'));
    await tester.pumpAndSettle();

    final saveAction = tester
        .widget<IconButton>(find.byKey(const Key('save-animal-button')))
        .onPressed!;
    saveAction();
    saveAction();
    await tester.pumpAndSettle();

    final animal = await AnimalRepository(database).getAnimalById(animalId);
    final media = await MediaRepository(database)
        .getMediaById(animal!.pictureMediaId!);
    final allMedia = await database.select(database.mediaAssets).get();

    expect(flow.selectedSources, [ImageSource.gallery]);
    expect(media, isNotNull);
    expect(media!.fileName, 'edited-animal.webp');
    expect(media.mimeType, 'image/webp');
    expect(media.data, normalizedTestPictureBytes);
    expect(await MediaRepository(database).getMediaById(oldMediaId), isNull);
    expect(allMedia, hasLength(1));
  });

  testWidgets('failed processing preserves the existing Animal picture', (
    tester,
  ) async {
    final existingBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final mediaId = await MediaRepository(database).createMedia(
      fileName: 'existing-animal.png',
      mimeType: 'image/png',
      data: existingBytes,
    );
    final animalId = await createTestAnimal(pictureMediaId: mediaId);
    final flow = FakePictureSelectionFlow(error: StateError('failed'));

    await pumpPage(tester, animalId: animalId, pictureSelectionFlow: flow);

    await tester.tap(find.byKey(const Key('select-picture-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictureSelectionControls.galleryOptionKey));
    await tester.pumpAndSettle();

    final animal = await AnimalRepository(database).getAnimalById(animalId);
    final media = await MediaRepository(database).getMediaById(mediaId);

    expect(find.text('Failed to select picture'), findsOneWidget);
    expect(find.text('Change Picture'), findsOneWidget);
    expect(animal!.pictureMediaId, mediaId);
    expect(media!.fileName, 'existing-animal.png');
    expect(media.data, existingBytes);
  });

  testWidgets('crop cancellation keeps the existing Animal picture unchanged', (
    tester,
  ) async {
    final existingBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final mediaId = await MediaRepository(database).createMedia(
      fileName: 'existing-animal.png',
      mimeType: 'image/png',
      data: existingBytes,
    );
    final animalId = await createTestAnimal(pictureMediaId: mediaId);
    final flow = FakePictureSelectionFlow(result: null);

    await pumpPage(tester, animalId: animalId, pictureSelectionFlow: flow);

    await tester.tap(find.byKey(const Key('select-picture-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictureSelectionControls.galleryOptionKey));
    await tester.pumpAndSettle();

    expect(flow.selectedSources, [ImageSource.gallery]);
    expect(find.text('Change Picture'), findsOneWidget);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    final animal = await AnimalRepository(database).getAnimalById(animalId);
    expect(animal!.pictureMediaId, mediaId);
    expect(await MediaRepository(database).getMediaById(mediaId), isNotNull);
  });
}
