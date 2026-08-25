import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';

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

  testWidgets('shows empty state when no boxes exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoxesPage(database: database),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No boxes available'), findsOneWidget);
  });

  testWidgets('shows boxes from database', (tester) async {
    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: BoxesPage(database: database),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('test-box-001'), findsOneWidget);
    expect(find.text('Box ID: 1'), findsOneWidget);
  });

  testWidgets('shows all boxes from database', (tester) async {
    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-002',
          ),
        );

    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-003',
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: BoxesPage(database: database),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('test-box-001'), findsOneWidget);
    expect(find.text('test-box-002'), findsOneWidget);
    expect(find.text('test-box-003'), findsOneWidget);
  });

  testWidgets('navigates to box detail when a box is selected', (tester) async {
    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: BoxesPage(database: database),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('test-box-001'));
    await tester.pumpAndSettle();

    expect(find.text('Box Details'), findsOneWidget);
    expect(find.text('Box Detail: test-box-001'), findsOneWidget);
  });
}