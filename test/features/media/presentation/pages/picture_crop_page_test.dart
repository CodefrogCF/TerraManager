import 'dart:convert';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/media/presentation/pages/picture_crop_page.dart';

Future<void> pumpUntil(
  WidgetTester tester, {
  required bool Function() condition,
  required String failureMessage,
}) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));

    if (condition()) {
      return;
    }

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }

  fail(failureMessage);
}

Future<void> pumpUntilCropIsReady(WidgetTester tester) async {
  final applyButton = find.byKey(PictureCropPage.applyButtonKey);

  await pumpUntil(
    tester,
    condition: () =>
        applyButton.evaluate().isNotEmpty &&
        tester.widget<TextButton>(applyButton).onPressed != null,
    failureMessage: 'Crop editor did not become ready',
  );
  await tester.pumpAndSettle();
}

void main() {
  final pictureBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVQI12P0'
    'WR/AwMDAxMDAwMDAAAAPqgFPj5eUQAAAAABJRU5ErkJggg==',
  );

  testWidgets('shows a free-form picture cropping screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PictureCropPage(imageBytes: pictureBytes)),
    );
    await pumpUntilCropIsReady(tester);

    expect(find.text('Crop Picture'), findsOneWidget);
    expect(
      find.text(
        'Move and resize the frame to choose the visible part of the picture.',
      ),
      findsOneWidget,
    );
    final cropFinder = find.byType(Crop);
    expect(cropFinder, findsOneWidget);
    expect(tester.widget<Crop>(cropFinder).key, PictureCropPage.editorKey);
    expect(find.byKey(PictureCropPage.cancelButtonKey), findsOneWidget);
    expect(find.byKey(PictureCropPage.applyButtonKey), findsOneWidget);

    final crop = tester.widget<Crop>(cropFinder);
    expect(crop.aspectRatio, isNull);
    expect(crop.interactive, isTrue);
  });

  testWidgets('cancel returns without replacing the selected picture', (
    tester,
  ) async {
    Uint8List? result = Uint8List.fromList([1]);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Uint8List>(
                    MaterialPageRoute(
                      builder: (_) => PictureCropPage(imageBytes: pictureBytes),
                    ),
                  );
                },
                child: const Text('Open cropper'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open cropper'));
    await pumpUntilCropIsReady(tester);
    await tester.tap(find.byKey(PictureCropPage.cancelButtonKey));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Open cropper'), findsOneWidget);
  });

  testWidgets('apply returns cropped bytes', (tester) async {
    Uint8List? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Uint8List>(
                    MaterialPageRoute(
                      builder: (_) => PictureCropPage(imageBytes: pictureBytes),
                    ),
                  );
                },
                child: const Text('Open cropper'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open cropper'));
    await pumpUntilCropIsReady(tester);

    final applyButton = find.byKey(PictureCropPage.applyButtonKey);
    expect(tester.widget<TextButton>(applyButton).onPressed, isNotNull);

    await tester.tap(applyButton);
    await pumpUntil(
      tester,
      condition: () => result != null,
      failureMessage: 'Crop operation did not return image bytes',
    );
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result, isNotEmpty);
    expect(find.text('Open cropper'), findsOneWidget);
  });
}
