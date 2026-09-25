import 'package:flutter/material.dart';
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
}
