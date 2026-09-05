import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_box_animals_page.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_scanner_page.dart';

const _targetQrId = 'TM:BOX:12345678-1234-4123-8123-123456789abc';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createAnimal({required int boxId, required String commonName}) {
    return AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: commonName,
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
  }

  testWidgets('shows the dedicated Feeding Mode scanner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FeedingScannerPage(database: database)),
    );

    await tester.pump();

    expect(find.text('Feeding Mode'), findsOneWidget);
    expect(find.byKey(const Key('feeding-mode-qr-scanner')), findsOneWidget);
  });

  testWidgets('shows an error for an invalid QR code', (tester) async {
    late Future<void> Function(String) scan;

    await tester.pumpWidget(
      MaterialApp(
        home: FeedingScannerPage(
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
    expect(find.byKey(const Key('feeding-mode-scanner-error')), findsOneWidget);
  });

  testWidgets('shows an error when the scanned Box does not exist', (
    tester,
  ) async {
    late Future<void> Function(String) scan;

    await tester.pumpWidget(
      MaterialApp(
        home: FeedingScannerPage(
          database: database,
          onHandlerReady: (handler) {
            scan = handler;
          },
        ),
      ),
    );

    await tester.pump();
    await scan(_targetQrId);
    await tester.pump();

    expect(find.text('Box not found'), findsOneWidget);
  });

  testWidgets('shows only active Animals assigned to the scanned Box', (
    tester,
  ) async {
    final targetBoxId = await BoxRepository(database).createBox(_targetQrId);
    final otherBoxId = await BoxRepository(database).createBox('other-box');

    final activeAnimalId = await createAnimal(
      boxId: targetBoxId,
      commonName: 'Active Snake',
    );

    final archivedAnimalId = await createAnimal(
      boxId: targetBoxId,
      commonName: 'Archived Snake',
    );

    await AnimalRepository(database).archiveAnimal(
      animalId: archivedAnimalId,
      reason: AnimalArchiveReason.rehomed,
      archivedAt: DateTime(2026, 9, 5),
    );

    await createAnimal(boxId: otherBoxId, commonName: 'Other Snake');

    late Future<void> Function(String) scan;
    var stopCalls = 0;
    var startCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FeedingScannerPage(
          database: database,
          onHandlerReady: (handler) {
            scan = handler;
          },
          stopScanner: () async {
            stopCalls++;
          },
          startScanner: () async {
            startCalls++;
          },
        ),
      ),
    );

    await tester.pump();

    final scanFuture = scan(_targetQrId);

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(FeedingBoxAnimalsPage), findsOneWidget);
    expect(find.text('Feeding – Box 1'), findsOneWidget);
    expect(find.text('1 active animal assigned to Box 1'), findsOneWidget);
    expect(find.text('Active Snake'), findsOneWidget);
    expect(find.text('Archived Snake'), findsNothing);
    expect(find.text('Other Snake'), findsNothing);
    expect(
      find.byKey(Key('feeding-mode-animal-$activeAnimalId')),
      findsOneWidget,
    );
    expect(stopCalls, 1);
    expect(startCalls, 0);

    await tester.tap(find.byKey(const Key('scan-another-box-button')));
    await tester.pumpAndSettle();
    await scanFuture;

    expect(find.text('Feeding Mode'), findsOneWidget);
    expect(startCalls, 1);
  });

  testWidgets('shows an empty state for a Box without active Animals', (
    tester,
  ) async {
    await BoxRepository(database).createBox(_targetQrId);

    late Future<void> Function(String) scan;

    await tester.pumpWidget(
      MaterialApp(
        home: FeedingScannerPage(
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

    final scanFuture = scan(_targetQrId);

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(FeedingBoxAnimalsPage), findsOneWidget);
    expect(find.text('No active animals assigned to Box 1'), findsOneWidget);
    expect(find.byKey(const Key('feeding-box-empty-message')), findsOneWidget);

    await tester.tap(find.byKey(const Key('scan-another-box-button')));
    await tester.pumpAndSettle();
    await scanFuture;
  });
}
