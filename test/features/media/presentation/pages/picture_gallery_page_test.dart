import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/features/media/presentation/pages/picture_gallery_page.dart';
import 'package:terramanager/features/media/presentation/widgets/picture_selection_controls.dart';

import '../fake_picture_selection_flow.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('Box gallery supports add, full screen, primary and delete', (
    tester,
  ) async {
    final boxId = await BoxRepository(database).createBox('gallery-box');
    final repository = PictureGalleryRepository(database);
    final firstId = await repository.addBoxPicture(
      boxId: boxId,
      fileName: 'first.webp',
      mimeType: 'image/webp',
      data: normalizedTestPictureBytes,
      capturedAt: DateTime.utc(2025, 1, 1),
    );
    final secondId = await repository.addBoxPicture(
      boxId: boxId,
      fileName: 'second.webp',
      mimeType: 'image/webp',
      data: normalizedTestPictureBytes,
      capturedAt: DateTime.utc(2025, 2, 1),
    );
    final flow = FakePictureSelectionFlow(
      cameraSupported: false,
      result: normalizedTestPicture('third.webp'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PictureGalleryPage(
          database: database,
          owner: PictureGalleryOwner.box,
          ownerId: boxId,
          pictureSelectionFlow: flow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('gallery-picture-$firstId')), findsOneWidget);
    expect(find.byKey(ValueKey('gallery-picture-$secondId')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('open-gallery-picture-$firstId')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('full-screen-image-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-full-screen-image-button')));
    await tester.pumpAndSettle();

    final setPrimary = find.byKey(ValueKey('set-primary-picture-$firstId'));
    await tester.ensureVisible(setPrimary);
    await tester.tap(setPrimary);
    await tester.pumpAndSettle();
    expect(
      (await BoxRepository(database).getBoxById(boxId))!.pictureMediaId,
      firstId,
    );

    final deleteSecond = find.byKey(
      ValueKey('delete-gallery-picture-$secondId'),
    );
    await tester.ensureVisible(deleteSecond);
    await tester.tap(deleteSecond);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-delete-gallery-picture-button')),
    );
    await tester.pumpAndSettle();
    expect(await MediaRepository(database).getMediaById(secondId), isNull);
    expect(await MediaRepository(database).getMediaById(firstId), isNotNull);

    final addButton = find.byKey(const Key('add-gallery-picture-button'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictureSelectionControls.galleryOptionKey));
    await tester.pumpAndSettle();

    final pictures = await repository.getBoxPictures(boxId);
    expect(pictures, hasLength(2));
    expect(pictures.last.media.fileName, 'third.webp');
    expect(pictures.last.isPrimary, isTrue);
  });
}
