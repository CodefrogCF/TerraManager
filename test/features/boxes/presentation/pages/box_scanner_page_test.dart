import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_scanner_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('shows scanner page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: BoxScannerPage(database: database)),
    );

    await tester.pump();

    expect(find.text('Scan Box'), findsOneWidget);

    expect(find.byKey(const Key('box-qr-scanner')), findsOneWidget);
  });

  testWidgets('shows error for invalid QR code', (tester) async {
    late Future<void> Function(String) scan;

    await tester.pumpWidget(
      MaterialApp(
        home: BoxScannerPage(
          database: database,
          onHandlerReady: (handler) {
            scan = handler;
          },
        ),
      ),
    );

    await tester.pump();

    await scan('https://example.com');

    await tester.pump();

    expect(find.text('Invalid TerraManager QR code'), findsOneWidget);

    expect(find.byKey(const Key('scanner-error')), findsOneWidget);
  });

  testWidgets('shows error when box does not exist', (tester) async {
    late Future<void> Function(String) scan;

    await tester.pumpWidget(
      MaterialApp(
        home: BoxScannerPage(
          database: database,
          onHandlerReady: (handler) {
            scan = handler;
          },
        ),
      ),
    );

    await tester.pump();

    await scan('TM:BOX:12345678-1234-4123-8123-123456789abc');

    await tester.pump();

    expect(find.text('Box not found'), findsOneWidget);
  });

  testWidgets('opens box detail for known QR code', (tester) async {
    const qrId = 'TM:BOX:12345678-1234-4123-8123-123456789abc';

    await BoxRepository(database).createBox(qrId);

    late Future<void> Function(String) scan;

    await tester.pumpWidget(
      MaterialApp(
        home: BoxScannerPage(
          database: database,
          onHandlerReady: (handler) {
            scan = handler;
          },
          stopScanner: () async {},
          startScanner: () async {},
        ),
      ),
    );

    await tester.pump();

    final scanFuture = scan(qrId);

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(BoxDetailPage), findsOneWidget);

    expect(find.text('Box Details'), findsOneWidget);

    expect(find.text(qrId), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await scanFuture;

    expect(find.text('Scan Box'), findsOneWidget);
  });
}
