import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/animals/presentation/widgets/animal_picture.dart';
import 'package:terramanager/features/boxes/presentation/widgets/box_picture.dart';
import 'package:terramanager/features/media/presentation/pages/full_screen_image_page.dart';

const _transparentPixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+'
    'A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  testWidgets('animal picture opens and closes the full-screen viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimalPicture(pictureBytes: base64Decode(_transparentPixelPng)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-animal-picture-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('full-screen-image-page')), findsOneWidget);
    expect(find.text('Animal picture'), findsOneWidget);
    expect(find.byKey(const Key('full-screen-image')), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-full-screen-image-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('full-screen-image-page')), findsNothing);
    expect(find.byType(AnimalPicture), findsOneWidget);
  });

  testWidgets('box picture opens and system Back closes the viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoxPicture(pictureBytes: base64Decode(_transparentPixelPng)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-box-picture-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('full-screen-image-page')), findsOneWidget);
    expect(find.text('Box picture'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('full-screen-image-page')), findsNothing);
    expect(find.byType(BoxPicture), findsOneWidget);
  });

  testWidgets('full-screen viewer enables zooming and panning', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FullScreenImagePage(
          imageBytes: base64Decode(_transparentPixelPng),
          title: 'Test picture',
        ),
      ),
    );

    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
      find.byKey(const Key('full-screen-image-viewer')),
    );

    expect(viewer.panEnabled, isTrue);
    expect(viewer.scaleEnabled, isTrue);
    expect(viewer.minScale, FullScreenImagePage.minimumScale);
    expect(viewer.maxScale, FullScreenImagePage.maximumScale);
    expect(viewer.maxScale, greaterThan(viewer.minScale));

    final image = tester.widget<Image>(
      find.byKey(const Key('full-screen-image')),
    );

    expect(image.fit, BoxFit.contain);
  });

  testWidgets('Animal placeholder is not tappable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AnimalPicture())),
    );

    expect(find.byKey(const Key('open-animal-picture-button')), findsNothing);

    await tester.tap(find.text('No picture'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('full-screen-image-page')), findsNothing);
  });

  testWidgets('Box placeholder is not tappable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BoxPicture())),
    );

    expect(find.byKey(const Key('open-box-picture-button')), findsNothing);

    await tester.tap(find.text('No picture'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('full-screen-image-page')), findsNothing);
  });
}
