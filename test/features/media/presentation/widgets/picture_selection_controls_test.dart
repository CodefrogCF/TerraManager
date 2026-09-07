import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:terramanager/features/media/presentation/widgets/picture_selection_controls.dart';

void main() {
  const actionButtonKey = Key('test-picture-action-button');
  const removeButtonKey = Key('test-remove-button');

  Widget buildControls({
    bool enabled = true,
    bool hasPicture = false,
    bool cameraSupported = true,
    required Future<void> Function(ImageSource source) onSelect,
    VoidCallback? onRemove,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PictureSelectionControls(
          enabled: enabled,
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
}
