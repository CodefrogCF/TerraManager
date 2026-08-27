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
    'shows new box form',
    (tester) async {
      await pumpPage(tester);

      expect(
        find.text('New Box'),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('qr-id-field')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('create-box-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'validates empty QR ID',
    (tester) async {
      await pumpPage(tester);

      await tester.tap(
        find.byKey(
          const Key('create-box-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a QR ID'),
        findsOneWidget,
      );

      final boxes = await BoxRepository(database).getAllBoxes();

      expect(
        boxes,
        isEmpty,
      );
    },
  );

  testWidgets(
    'creates box in database',
    (tester) async {
      await pumpPageWithNavigation(tester);

      await tester.enterText(
        find.byKey(const Key('qr-id-field')),
        'test-box-new-001',
      );

      await tester.tap(
        find.byKey(
          const Key('create-box-button'),
        ),
      );

      await tester.pumpAndSettle();

      final box = await BoxRepository(database).getBoxByQrId(
        'test-box-new-001',
      );

      expect(
        box,
        isNotNull,
      );

      expect(
        box!.qrId,
        'test-box-new-001',
      );
    },
  );

  testWidgets(
    'returns to previous page after successful save',
    (tester) async {
      await pumpPageWithNavigation(tester);

      await tester.enterText(
        find.byKey(const Key('qr-id-field')),
        'test-box-new-002',
      );

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

  testWidgets(
    'shows error when QR ID already exists',
    (tester) async {
      await BoxRepository(database).createBox(
        'duplicate-box',
      );

      await pumpPage(tester);

      await tester.enterText(
        find.byKey(const Key('qr-id-field')),
        'duplicate-box',
      );

      await tester.tap(
        find.byKey(
          const Key('create-box-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Failed to create box'),
        findsOneWidget,
      );

      expect(
        find.text('New Box'),
        findsOneWidget,
      );
    },
  );
}