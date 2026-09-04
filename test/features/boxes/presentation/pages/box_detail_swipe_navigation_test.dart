import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/qr/qr_export_service.dart';
import 'package:terramanager/core/qr/qr_file_name.dart';
import 'package:terramanager/core/qr/qr_print_service.dart';
import 'package:terramanager/core/qr/qr_storage_service.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_edit_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/features/navigation/domain/detail_navigation_context.dart';

class RecordingQrExporter implements QrExporter {
  final List<String> exportedQrIds = [];

  @override
  Future<Uint8List> exportPng({
    required String qrId,
    double size = 1024,
  }) async {
    exportedQrIds.add(qrId);

    return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
  }
}

class RecordingQrStorage implements QrStorage {
  String? savedFileName;

  @override
  Future<String> savePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    savedFileName = fileName;

    return fileName;
  }
}

class RecordingQrPrinter implements QrPrinter {
  String? printedQrId;

  @override
  Future<void> printQrCode({
    required Uint8List pngBytes,
    required String qrId,
  }) async {
    printedQrId = qrId;
  }
}

void main() {
  late AppDatabase database;
  late BoxRepository boxRepository;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    boxRepository = BoxRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Box> createBox(String qrId, {double? widthCm}) async {
    final boxId = await boxRepository.createBox(qrId, widthCm: widthCm);
    final box = await boxRepository.getBoxById(boxId);

    return box!;
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required Box box,
    required List<int> boxIds,
    QrExporter qrExporter = const QrExportService(),
    QrStorage qrStorage = const QrStorageService(),
    QrPrinter qrPrinter = const QrPrintService(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoxDetailPage(
          database: database,
          box: box,
          navigationContext: DetailNavigationContext.boxes(
            boxIds: boxIds,
            currentBoxId: box.id,
          ),
          qrExporter: qrExporter,
          qrStorage: qrStorage,
          qrPrinter: qrPrinter,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> swipeLeft(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('box-detail-swipe-area')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeRight(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('box-detail-swipe-area')),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('swipes through boxes in source order with safe boundaries', (
    tester,
  ) async {
    final firstBox = await createBox('box-one');
    final secondBox = await createBox('box-two');
    final thirdBox = await createBox('box-three');
    final boxIds = [firstBox.id, secondBox.id, thirdBox.id];

    await pumpDetail(tester, box: secondBox, boxIds: boxIds);

    expect(find.text('Box ${secondBox.id}'), findsOneWidget);

    await swipeLeft(tester);
    expect(find.text('Box ${thirdBox.id}'), findsOneWidget);

    await swipeLeft(tester);
    expect(find.text('Box ${thirdBox.id}'), findsOneWidget);

    await swipeRight(tester);
    expect(find.text('Box ${secondBox.id}'), findsOneWidget);

    await swipeRight(tester);
    expect(find.text('Box ${firstBox.id}'), findsOneWidget);

    await swipeRight(tester);
    expect(find.text('Box ${firstBox.id}'), findsOneWidget);
  });

  testWidgets('editing refreshes the currently displayed box', (tester) async {
    final firstBox = await createBox('edit-box-one', widthCm: 10);
    final secondBox = await createBox('edit-box-two', widthCm: 20);

    await pumpDetail(
      tester,
      box: firstBox,
      boxIds: [firstBox.id, secondBox.id],
    );

    await swipeLeft(tester);

    await tester.tap(find.byKey(const Key('edit-box-button')));
    await tester.pumpAndSettle();

    final editPage = tester.widget<BoxEditPage>(find.byType(BoxEditPage));

    expect(editPage.boxId, secondBox.id);

    final widthField = find.byKey(const Key('box-width-field'));

    await tester.scrollUntilVisible(
      widthField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(widthField, '75');
    await tester.tap(find.byKey(const Key('save-box-button')));
    await tester.pumpAndSettle();

    final updatedFirstBox = await boxRepository.getBoxById(firstBox.id);
    final updatedSecondBox = await boxRepository.getBoxById(secondBox.id);

    expect(updatedFirstBox!.widthCm, 10);
    expect(updatedSecondBox!.widthCm, 75);

    await tester.scrollUntilVisible(
      find.byKey(const Key('box-width-row')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('75 cm'), findsOneWidget);
  });

  testWidgets('QR actions use the currently displayed box', (tester) async {
    final firstBox = await createBox('qr-box-one');
    final secondBox = await createBox('qr-box-two');
    final exporter = RecordingQrExporter();
    final storage = RecordingQrStorage();
    final printer = RecordingQrPrinter();

    await pumpDetail(
      tester,
      box: firstBox,
      boxIds: [firstBox.id, secondBox.id],
      qrExporter: exporter,
      qrStorage: storage,
      qrPrinter: printer,
    );

    await swipeLeft(tester);

    await tester.tap(find.byKey(const Key('save-qr-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('print-qr-button')));
    await tester.pumpAndSettle();

    expect(exporter.exportedQrIds, [secondBox.qrId, secondBox.qrId]);
    expect(storage.savedFileName, buildBoxQrFileName(secondBox.qrId));
    expect(printer.printedQrId, secondBox.qrId);
  });

  testWidgets('deleting the swiped box safely returns to the overview', (
    tester,
  ) async {
    final firstBox = await createBox('delete-box-one');
    final secondBox = await createBox('delete-box-two');
    final thirdBox = await createBox('delete-box-three');

    await tester.pumpWidget(MaterialApp(home: BoxesPage(database: database)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('box-list-item-${firstBox.id}')));
    await tester.pumpAndSettle();

    await swipeLeft(tester);
    expect(find.text('Box ${secondBox.id}'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-box-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-box-button')));
    await tester.pumpAndSettle();

    expect(await boxRepository.getBoxById(secondBox.id), isNull);
    expect(find.text('Boxes'), findsOneWidget);
    expect(find.text('Box ${firstBox.id}'), findsOneWidget);
    expect(find.text('Box ${secondBox.id}'), findsNothing);
    expect(find.text('Box ${thirdBox.id}'), findsOneWidget);
  });

  testWidgets('skips a missing adjacent box without invalid state', (
    tester,
  ) async {
    final firstBox = await createBox('missing-box-one');
    final secondBox = await createBox('missing-box-two');
    final thirdBox = await createBox('missing-box-three');

    await pumpDetail(
      tester,
      box: firstBox,
      boxIds: [firstBox.id, secondBox.id, thirdBox.id],
    );

    await boxRepository.deleteBox(secondBox.id);

    await swipeLeft(tester);

    expect(find.text('Box ${firstBox.id}'), findsOneWidget);
    expect(find.byKey(const Key('box-refresh-error')), findsOneWidget);

    await swipeLeft(tester);

    expect(find.text('Box ${thirdBox.id}'), findsOneWidget);
    expect(find.byKey(const Key('box-refresh-error')), findsNothing);
  });

  testWidgets('back returns to the original box overview', (tester) async {
    final firstBox = await createBox('back-box-one');
    final secondBox = await createBox('back-box-two');

    await tester.pumpWidget(MaterialApp(home: BoxesPage(database: database)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('box-list-item-${firstBox.id}')));
    await tester.pumpAndSettle();

    await swipeLeft(tester);
    expect(find.text('Box ${secondBox.id}'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Boxes'), findsOneWidget);
    expect(find.byKey(const Key('box-detail-title')), findsNothing);
    expect(find.text('Box ${firstBox.id}'), findsOneWidget);
    expect(find.text('Box ${secondBox.id}'), findsOneWidget);
  });
}
