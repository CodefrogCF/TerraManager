import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/presentation/widgets/responsive_picture_frame.dart';
import 'package:terramanager/features/animals/presentation/widgets/animal_picture.dart';
import 'package:terramanager/features/boxes/presentation/widgets/box_picture.dart';

const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+'
    'A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  for (final box in [false, true]) {
    testWidgets(
      '${box ? 'Box' : 'Animal'} preview adapts without state jumps',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final width in [390.0, 844.0, 1920.0]) {
          tester.view.physicalSize = Size(width, 900);
          Size? missingSize;
          for (final hasPicture in [false, true]) {
            final bytes = hasPicture ? base64Decode(_pixel) : null;
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: box
                      ? BoxPicture(pictureBytes: bytes)
                      : AnimalPicture(pictureBytes: bytes),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final size = tester.getSize(
              find
                  .descendant(
                    of: find.byType(ResponsivePictureFrame),
                    matching: find.byType(SizedBox),
                  )
                  .first,
            );
            expect(size.width, lessThanOrEqualTo(760));
            expect(size.height, width == 390 ? 220 : 360);
            if (!hasPicture) missingSize = size;
            expect(size, missingSize);
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  }

  testWidgets('an explicit preview height is still respected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AnimalPicture(height: 150))),
    );
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(ResponsivePictureFrame),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .height,
      150,
    );
  });
}
