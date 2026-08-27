import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/new_box_page.dart';

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

  Future<void> pumpPage(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewBoxPage(
          database: database,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> pumpPageWithNavigation(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-new-box-button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NewBoxPage(
                          database: database,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open New Box'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const Key('open-new-box-button'),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows new box screen',
    (tester) async {
      await pumpPage(tester);

      expect(
        find.text('New Box'),
        findsOneWidget,
      );

      expect(
        find.text('Create a new box'),
        findsOneWidget,
      );

      expect(
        find.text(
          'A unique QR identifier will be generated automatically '
          'for this box.',
        ),
        findsOneWidget,
      );

      expect(
        find.text('Format: TM:BOX:<UUID>'),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key('create-box-button'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'does not require manual QR ID',
    (tester) async {
      await pumpPage(tester);

      expect(
        find.byType(TextFormField),
        findsNothing,
      );

      expect(
        find.byKey(
          const Key('qr-id-field'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'creates box with generated QR ID',
    (tester) async {
      await pumpPageWithNavigation(tester);

      await tester.tap(
        find.byKey(
          const Key('create-box-button'),
        ),
      );

      await tester.pumpAndSettle();

      final boxes =
          await BoxRepository(database).getAllBoxes();

      expect(
        boxes.length,
        1,
      );

      final box = boxes.single;

      expect(
        box.qrId,
        startsWith('TM:BOX:'),
      );

      expect(
        box.qrId,
        matches(
          RegExp(
            r'^TM:BOX:'
            r'[0-9a-f]{8}-'
            r'[0-9a-f]{4}-'
            r'4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
    },
  );

  testWidgets(
    'returns to previous page after successful creation',
    (tester) async {
      await pumpPageWithNavigation(tester);

      await tester.tap(
        find.byKey(
          const Key('create-box-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('New Box'),
        findsNothing,
      );

      expect(
        find.text('Open New Box'),
        findsOneWidget,
      );
    },
  );
}