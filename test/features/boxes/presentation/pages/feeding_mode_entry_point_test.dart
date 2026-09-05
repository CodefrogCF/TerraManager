import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_scanner_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_scanner_page.dart';

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

  testWidgets('Feeding Mode button opens the dedicated scanner', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.byKey(const Key('feeding-mode-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feeding-mode-button')));
    await tester.pumpAndSettle();

    expect(find.byType(FeedingScannerPage), findsOneWidget);
    expect(find.text('Feeding Mode'), findsOneWidget);
    expect(find.byType(BoxScannerPage), findsNothing);
  });

  testWidgets('normal scan button still opens the Box scanner', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('scan-box-button')));
    await tester.pumpAndSettle();

    expect(find.byType(BoxScannerPage), findsOneWidget);
    expect(find.text('Scan Box'), findsOneWidget);
    expect(find.byType(FeedingScannerPage), findsNothing);
  });
}
