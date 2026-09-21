import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_scanner_page.dart';
import 'package:terramanager/features/scanning/presentation/widgets/scanner_torch_button.dart';

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
    expect(find.byType(ScannerTorchButton), findsOneWidget);
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

  testWidgets('selection mode forwards scanned active Box to callback', (
    tester,
  ) async {
    const qrId = 'TM:BOX:87654321-4321-4123-8123-cba987654321';

    final boxId = await BoxRepository(database)
        .createBox(qrId, name: 'Target Box');

    late Future<void> Function(String) scan;

    Box? scannedBox;

    await tester.pumpWidget(
      MaterialApp(
        home: BoxScannerPage(
          database: database,
          onHandlerReady: (handler) {
            scan = handler;
          },
          stopScanner: () async {},
          startScanner: () async {},
          onBoxScanned: (box) async {
            scannedBox = box;

            return false;
          },
        ),
      ),
    );

    await tester.pump();

    await scan(qrId);
    await tester.pumpAndSettle();

    expect(scannedBox, isNotNull);
    expect(scannedBox!.id, boxId);
    expect(scannedBox!.qrId, qrId);
    expect(scannedBox!.name, 'Target Box');

    expect(find.byType(BoxDetailPage), findsNothing);

    // Returning false keeps the scanner open.
    expect(find.byType(BoxScannerPage), findsOneWidget);
  });

  testWidgets('selection mode closes scanner when callback accepts Box', (
    tester,
  ) async {
    const qrId = 'TM:BOX:abcdef12-3456-4789-8123-abcdef123456';

    await BoxRepository(database).createBox(qrId);

    late Future<void> Function(String) scan;

    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                key: const Key('open-scanner-button'),
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => BoxScannerPage(
                        database: database,
                        onHandlerReady: (handler) {
                          scan = handler;
                        },
                        stopScanner: () async {},
                        startScanner: () async {},
                        onBoxScanned: (_) async => true,
                      ),
                    ),
                  );
                },
                child: const Text('Open Scanner'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-scanner-button')));
    await tester.pumpAndSettle();

    await scan(qrId);
    await tester.pumpAndSettle();

    expect(find.byType(BoxScannerPage), findsNothing);
    expect(result, isTrue);
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

    expect(find.byKey(const Key('box-detail-title')), findsOneWidget);

    expect(find.text('Box 1'), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(const Key('box-qr-id')), 300);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('box-qr-id')), findsOneWidget);

    expect(
      find.text('TM:BOX:12345678-1234-4123-8123-123456789abc'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    await scanFuture;

    expect(find.text('Scan Box'), findsOneWidget);
  });
}
