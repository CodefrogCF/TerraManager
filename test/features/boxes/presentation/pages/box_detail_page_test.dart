import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/widgets/box_qr_code.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(
      NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<Box> createTestBox() async {
    final boxId = await BoxRepository(database).createBox(
      'TM:BOX:12345678-1234-4123-8123-123456789abc',
    );

    final box = await BoxRepository(database).getBoxById(
      boxId,
    );

    return box!;
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required Box box,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoxDetailPage(
          box: box,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows box details',
    (tester) async {
      final box = await createTestBox();

      await pumpPage(
        tester,
        box: box,
      );

      expect(
        find.text('Box Details'),
        findsOneWidget,
      );

      expect(
        find.text(
          'TM:BOX:12345678-1234-4123-8123-123456789abc',
        ),
        findsOneWidget,
      );

      expect(
        find.text('Box ID'),
        findsOneWidget,
      );

      expect(
        find.text(box.id.toString()),
        findsOneWidget,
      );

      expect(
        find.text('Created'),
        findsOneWidget,
      );

      expect(
        find.text('Updated'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows QR code',
    (tester) async {
      final box = await createTestBox();

      await pumpPage(
        tester,
        box: box,
      );

      expect(
        find.byKey(
          const Key('box-qr-code'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key('box-qr-image'),
        ),
        findsOneWidget,
      );

      expect(
        find.byType(QrImageView),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'QR code receives box QR ID',
    (tester) async {
      final box = await createTestBox();

      await pumpPage(
        tester,
        box: box,
      );

      final boxQrCode = tester.widget<BoxQrCode>(
        find.byKey(
          const Key('box-qr-code'),
        ),
      );

      expect(
        boxQrCode.qrId,
        box.qrId,
      );
    },
  );

  testWidgets(
    'back navigation returns to previous page',
    (tester) async {
      final box = await createTestBox();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  key: const Key('open-box-detail-button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BoxDetailPage(
                          box: box,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Box'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const Key('open-box-detail-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Box Details'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        find.text('Box Details'),
        findsNothing,
      );

      expect(
        find.text('Open Box'),
        findsOneWidget,
      );
    },
  );
}