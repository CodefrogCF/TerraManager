import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';

void main() {
  testWidgets('content is capped on desktop and fills a phone', (tester) async {
    const childKey = Key('content');
    Future<void> pumpAt(double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConstrainedPageWidth(
              maxWidth: 760,
              child: ColoredBox(key: childKey, color: Colors.blue),
            ),
          ),
        ),
      );
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAt(1600);
    expect(tester.getSize(find.byKey(childKey)).width, 760);
    await pumpAt(390);
    expect(tester.getSize(find.byKey(childKey)).width, 390);
  });

  for (final brightness in Brightness.values) {
    testWidgets('outer margins paint the $brightness page background', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = ThemeData(brightness: brightness);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RepaintBoundary(
            key: boundaryKey,
            child: const ConstrainedPageWidth(
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData())!;
        final color = theme.scaffoldBackgroundColor.toARGB32();
        for (final x in [10, 1590]) {
          final pixel = (100 * image.width + x) * 4;
          expect(bytes.getUint8(pixel), (color >> 16) & 255);
          expect(bytes.getUint8(pixel + 1), (color >> 8) & 255);
          expect(bytes.getUint8(pixel + 2), color & 255);
          expect(bytes.getUint8(pixel + 3), 255);
        }
        image.dispose();
      });
    });
  }
}
