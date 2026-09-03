import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: BoxesPage(database: database)));

    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state when no boxes exist', (tester) async {
    await pumpPage(tester);

    expect(find.text('No boxes available'), findsOneWidget);
  });

  testWidgets('shows human readable box label', (tester) async {
    await BoxRepository(database).createBox('test-box-001');

    await pumpPage(tester);

    expect(find.text('Box 1'), findsOneWidget);

    expect(find.text('Dimensions not specified'), findsOneWidget);

    expect(find.text('test-box-001'), findsNothing);
  });

  testWidgets('shows box dimensions in overview', (tester) async {
    await BoxRepository(database)
        .createBox('test-box-001', widthCm: 60, heightCm: 45, depthCm: 40);

    await pumpPage(tester);

    expect(find.text('Box 1'), findsOneWidget);

    expect(find.text('60 × 45 × 40 cm'), findsOneWidget);
  });

  testWidgets('shows multiple boxes by local box id', (tester) async {
    await BoxRepository(database).createBox('test-box-001');

    await BoxRepository(database).createBox('test-box-002');

    await pumpPage(tester);

    expect(find.text('Box 1'), findsOneWidget);
    expect(find.text('Box 2'), findsOneWidget);

    expect(find.text('test-box-001'), findsNothing);

    expect(find.text('test-box-002'), findsNothing);
  });

  testWidgets('opens box detail page', (tester) async {
    await BoxRepository(database).createBox('test-box-detail');

    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('box-list-item-1')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('box-detail-title')), findsOneWidget);

    expect(find.text('Box 1'), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(const Key('box-qr-id')), 300);

    await tester.pumpAndSettle();

    expect(find.text('test-box-detail'), findsOneWidget);
  });

  testWidgets('add button opens new box page', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const Key('add-box-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-box-button')));

    await tester.pumpAndSettle();

    expect(find.text('New Box'), findsOneWidget);

    expect(find.byKey(const Key('create-box-button')), findsOneWidget);

    expect(find.byKey(const Key('qr-id-field')), findsNothing);
  });

  testWidgets('newly created box appears with readable label', (tester) async {
    await pumpPage(tester);

    expect(find.text('No boxes available'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-box-button')));

    await tester.pumpAndSettle();

    final createButton = find.byKey(const Key('create-box-button'));

    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();

    await tester.tap(createButton);
    await tester.pumpAndSettle();

    final boxes = await BoxRepository(database).getAllBoxes();

    expect(boxes.length, 1);

    final box = boxes.single;

    expect(box.qrId, startsWith('TM:BOX:'));

    expect(find.text('Box 1'), findsOneWidget);

    expect(find.text(box.qrId), findsNothing);
  });

  testWidgets('box ids are not renumbered after deletion', (tester) async {
    final repository = BoxRepository(database);

    await repository.createBox('box-1');

    final secondId = await repository.createBox('box-2');

    await repository.createBox('box-3');

    await repository.deleteBox(secondId);

    final fourthId = await repository.createBox('box-4');

    expect(fourthId, 4);

    await pumpPage(tester);

    expect(find.text('Box 1'), findsOneWidget);
    expect(find.text('Box 2'), findsNothing);
    expect(find.text('Box 3'), findsOneWidget);
    expect(find.text('Box 4'), findsOneWidget);
  });
}
