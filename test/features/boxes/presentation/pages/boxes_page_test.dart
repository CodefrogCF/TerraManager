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

  testWidgets('shows box from database', (tester) async {
    await BoxRepository(database).createBox('test-box-001');

    await pumpPage(tester);

    expect(find.text('test-box-001'), findsOneWidget);

    expect(find.text('Box ID: 1'), findsOneWidget);
  });

  testWidgets('shows multiple boxes', (tester) async {
    await BoxRepository(database).createBox('test-box-001');

    await BoxRepository(database).createBox('test-box-002');

    await pumpPage(tester);

    expect(find.text('test-box-001'), findsOneWidget);

    expect(find.text('test-box-002'), findsOneWidget);
  });

  testWidgets('opens box detail page', (tester) async {
    await BoxRepository(database).createBox('test-box-detail');

    await pumpPage(tester);

    await tester.tap(find.text('test-box-detail'));

    await tester.pumpAndSettle();

    expect(find.text('Box Details'), findsOneWidget);

    expect(find.text('test-box-detail'), findsWidgets);
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

  testWidgets('newly created box appears in overview', (tester) async {
    await pumpPage(tester);

    expect(find.text('No boxes available'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-box-button')));

    await tester.pumpAndSettle();

    expect(find.text('New Box'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-box-button')));

    await tester.pumpAndSettle();

    expect(find.text('Boxes'), findsOneWidget);

    expect(find.text('No boxes available'), findsNothing);

    final boxes = await BoxRepository(database).getAllBoxes();

    expect(boxes.length, 1);

    final box = boxes.single;

    expect(box.qrId, startsWith('TM:BOX:'));

    expect(find.text(box.qrId), findsOneWidget);
  });
}
