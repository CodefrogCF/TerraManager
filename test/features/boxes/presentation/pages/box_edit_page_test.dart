import 'dart:async';
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
    final boxId = await BoxRepository(database)
        .createBox('test-box-001', pictureMediaId: mediaId);

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

  testWidgets('atomically stores one normalized Box replacement', (
    tester,
  ) async {
    final existingBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final oldMediaId = await MediaRepository(database).createMedia(
      fileName: 'existing-box.png',
      mimeType: 'image/png',
      data: existingBytes,
    );
    final selection = Completer<SelectedPicture?>();
    final flow = FakePictureSelectionFlow(pendingResult: selection.future);
    final boxId = await BoxRepository(database)
        .createBox('test-box-001', pictureMediaId: oldMediaId);

    await pumpPage(tester, boxId: boxId, pictureSelectionFlow: flow);

    await tester.tap(find.byKey(const Key('select-box-picture-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictureSelectionControls.cameraOptionKey));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(
      find.byKey(PictureSelectionControls.processingIndicatorKey),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('save-box-button')))
          .onPressed,
      isNull,
    );
    expect(await MediaRepository(database).getMediaById(oldMediaId), isNotNull);

    selection.complete(normalizedTestPicture('edited-box.webp'));
    await tester.pumpAndSettle();

    final saveAction = tester
        .widget<IconButton>(find.byKey(const Key('save-box-button')))
        .onPressed!;
    saveAction();
    saveAction();
    await tester.pumpAndSettle();

    final box = await BoxRepository(database).getBoxById(boxId);
    final media = await MediaRepository(database)
        .getMediaById(box!.pictureMediaId!);
    final allMedia = await database.select(database.mediaAssets).get();

    expect(flow.selectedSources, [ImageSource.camera]);
    expect(media, isNotNull);
    expect(media!.fileName, 'edited-box.webp');
    expect(media.mimeType, 'image/webp');
    expect(media.data, normalizedTestPictureBytes);
    expect(await MediaRepository(database).getMediaById(oldMediaId), isNull);
    expect(allMedia, hasLength(1));
  });

  testWidgets('failed processing preserves the existing Box picture', (
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
    final boxId = await BoxRepository(database)
        .createBox('test-box-001', pictureMediaId: mediaId);
    final flow = FakePictureSelectionFlow(error: StateError('failed'));

    await pumpPage(tester, boxId: boxId, pictureSelectionFlow: flow);

    await tester.tap(find.byKey(const Key('select-box-picture-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictureSelectionControls.galleryOptionKey));
    await tester.pumpAndSettle();

    final box = await BoxRepository(database).getBoxById(boxId);
    final media = await MediaRepository(database).getMediaById(mediaId);

    expect(find.text('Failed to select picture'), findsOneWidget);
    expect(find.text('Change Picture'), findsOneWidget);
    expect(box!.pictureMediaId, mediaId);
    expect(media!.fileName, 'existing-box.png');
    expect(media.data, existingBytes);
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
    final boxId = await BoxRepository(database)
        .createBox('test-box-001', pictureMediaId: mediaId);
    final flow = FakePictureSelectionFlow(result: null);

    await pumpPage(tester, boxId: boxId, pictureSelectionFlow: flow);

    await tester.tap(find.byKey(const Key('select-box-picture-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictureSelectionControls.galleryOptionKey));
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
