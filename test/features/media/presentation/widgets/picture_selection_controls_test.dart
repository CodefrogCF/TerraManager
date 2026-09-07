import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:terramanager/features/media/presentation/widgets/picture_selection_controls.dart';

void main() {
  const actionButtonKey = Key('test-picture-action-button');
  const removeButtonKey = Key('test-remove-button');

  Widget buildControls({
    bool enabled = true,
    bool processing = false,
    bool hasPicture = false,
    bool cameraSupported = true,
    required Future<void> Function(ImageSource source) onSelect,
    VoidCallback? onRemove,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PictureSelectionControls(
          enabled: enabled,
          processing: processing,
          hasPicture: hasPicture,
          cameraSupported: cameraSupported,
          onSelect: onSelect,
          onRemove: onRemove ?? () {},
          actionButtonKey: actionButtonKey,
          removeButtonKey: removeButtonKey,
        ),
      ),
    );
  }

  testWidgets('shows one Add Picture action and then offers both sources', (
    tester,
  ) async {
    final selectedSources = <ImageSource>[];

    await tester.pumpWidget(
      buildControls(
        onSelect: (source) async {
          selectedSources.add(source);
        },
      ),
    );

    expect(find.text('Add Picture'), findsOneWidget);
    expect(find.text('Take Photo'), findsNothing);
    expect(find.text('Choose from Gallery'), findsNothing);
    expect(find.byType(OutlinedButton), findsOneWidget);

    await tester.tap(find.byKey(actionButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Choose Picture Source'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);

    await tester.tap(find.byKey(PictureSelectionControls.cameraOptionKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(actionButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictureSelectionControls.galleryOptionKey));
    await tester.pumpAndSettle();

    expect(selectedSources, [ImageSource.camera, ImageSource.gallery]);
  });

  testWidgets('disables only the camera action when it is unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildControls(cameraSupported: false, onSelect: (_) async {}),
    );

    await tester.tap(find.byKey(actionButtonKey));
    await tester.pumpAndSettle();

    final cameraOption = tester.widget<ListTile>(
      find.byKey(PictureSelectionControls.cameraOptionKey),
    );
    final galleryOption = tester.widget<ListTile>(
      find.byKey(PictureSelectionControls.galleryOptionKey),
    );

    expect(cameraOption.enabled, isFalse);
    expect(galleryOption.enabled, isTrue);
    expect(find.text('Camera unavailable'), findsOneWidget);
  });

  testWidgets('shows Change Picture and removal when a picture exists', (
    tester,
  ) async {
    var removeCalls = 0;

    await tester.pumpWidget(
      buildControls(
        hasPicture: true,
        onSelect: (_) async {},
        onRemove: () {
          removeCalls++;
        },
      ),
    );

    expect(find.text('Change Picture'), findsOneWidget);
    expect(find.text('Add Picture'), findsNothing);
    expect(find.text('Take Photo'), findsNothing);
    expect(find.text('Choose from Gallery'), findsNothing);
    expect(find.byType(OutlinedButton), findsOneWidget);

    await tester.tap(find.byKey(removeButtonKey));
    await tester.pump();

    expect(removeCalls, 1);
  });

  testWidgets('shows progress and disables picture actions while processing', (
    tester,
  ) async {
    var selectCalls = 0;
    var removeCalls = 0;

    await tester.pumpWidget(
      buildControls(
        processing: true,
        hasPicture: true,
        onSelect: (_) async {
          selectCalls++;
        },
        onRemove: () {
          removeCalls++;
        },
      ),
    );

    expect(
      find.byKey(PictureSelectionControls.processingIndicatorKey),
      findsOneWidget,
    );
    expect(find.text('Processing picture...'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(actionButtonKey)).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.byKey(removeButtonKey)).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(actionButtonKey), warnIfMissed: false);
    await tester.tap(find.byKey(removeButtonKey), warnIfMissed: false);

    expect(selectCalls, 0);
    expect(removeCalls, 0);
  });
}
