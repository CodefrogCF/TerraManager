import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_edit_page.dart';
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

  Future<void> pumpPage(
    WidgetTester tester, {
    required int boxId,
    PictureSelectionFlow? pictureSelectionFlow,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoxEditPage(
          database: database,
          boxId: boxId,
          pictureSelectionFlow: pictureSelectionFlow,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows one Add Picture action without an existing picture', (
    tester,
  ) async {
    final boxId = await BoxRepository(database).createBox('test-box-001');

    await pumpPage(tester, boxId: boxId);

    expect(find.byKey(const Key('select-box-picture-button')), findsOneWidget);
    expect(find.text('Add Picture'), findsOneWidget);
    expect(find.byKey(const Key('remove-box-picture-button')), findsNothing);
  });

  testWidgets('shows Change Picture and delete for an existing picture', (
    tester,
  ) async {
    final mediaId = await MediaRepository(database).createMedia(
      fileName: 'box.png',
      mimeType: 'image/png',
      data: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    final boxId = await BoxRepository(database).createBox(
      'test-box-001',
      pictureMediaId: mediaId,
    );

    await pumpPage(tester, boxId: boxId);

    expect(find.byKey(const Key('select-box-picture-button')), findsOneWidget);
    expect(find.text('Change Picture'), findsOneWidget);
    expect(find.byKey(const Key('remove-box-picture-button')), findsOneWidget);

    expect(find.text('Take Photo'), findsNothing);
    expect(find.text('Choose from Gallery'), findsNothing);

    await tester.tap(find.byKey(const Key('select-box-picture-button')));
    await tester.pumpAndSettle();

    expect(find.text('Choose Picture Source'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });

  testWidgets('stores cropped replacement bytes when editing a Box', (
    tester,
  ) async {
    final pictureBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final flow = FakePictureSelectionFlow(
      result: SelectedPicture(
        bytes: pictureBytes,
        fileName: 'edited-box.png',
        mimeType: 'image/png',
      ),
    );
    final boxId = await BoxRepository(database).createBox('test-box-001');

    await pumpPage(
      tester,
      boxId: boxId,
      pictureSelectionFlow: flow,
    );

    await tester.tap(find.byKey(const Key('select-box-picture-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(PictureSelectionControls.galleryOptionKey),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-box-button')));
    await tester.pumpAndSettle();

    final box = await BoxRepository(database).getBoxById(boxId);
    final media = await MediaRepository(database).getMediaById(
      box!.pictureMediaId!,
    );

    expect(flow.selectedSources, [ImageSource.gallery]);
    expect(media, isNotNull);
    expect(media!.fileName, 'edited-box.png');
    expect(media.data, pictureBytes);
  });

  testWidgets('crop cancellation keeps the existing Box picture unchanged', (
    tester,
  ) async {
    final existingBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final mediaId = await MediaRepository(database).createMedia(
      fileName: 'existing-box.png',
      mimeType: 'image/png',
      data: existingBytes,
    );
    final boxId = await BoxRepository(database).createBox(
      'test-box-001',
      pictureMediaId: mediaId,
    );
    final flow = FakePictureSelectionFlow(result: null);

    await pumpPage(
      tester,
      boxId: boxId,
      pictureSelectionFlow: flow,
    );

    await tester.tap(find.byKey(const Key('select-box-picture-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(PictureSelectionControls.galleryOptionKey),
    );
    await tester.pumpAndSettle();

    expect(flow.selectedSources, [ImageSource.gallery]);
    expect(find.text('Change Picture'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-box-button')));
    await tester.pumpAndSettle();

    final box = await BoxRepository(database).getBoxById(boxId);
    expect(box!.pictureMediaId, mediaId);
    expect(await MediaRepository(database).getMediaById(mediaId), isNotNull);
  });
}
