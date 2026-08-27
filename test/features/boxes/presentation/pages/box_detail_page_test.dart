import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:terramanager/core/qr/qr_export_service.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/widgets/box_qr_code.dart';
import 'package:terramanager/core/qr/qr_storage_service.dart';
import 'package:terramanager/core/qr/qr_file_name.dart';

class FakeQrExporter implements QrExporter {
  String? exportedQrId;

  @override
  Future<Uint8List> exportPng({
    required String qrId,
    double size = 1024,
  }) async {
    exportedQrId = qrId;

    return Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      1,
    ]);
  }
}

class FailingQrExporter implements QrExporter {
  @override
  Future<Uint8List> exportPng({
    required String qrId,
    double size = 1024,
  }) {
    throw StateError('Test export failure');
  }
}

class FakeQrStorage implements QrStorage {
  Uint8List? savedBytes;
  String? savedFileName;

  @override
  Future<String> savePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    savedBytes = bytes;
    savedFileName = fileName;

    return fileName;
  }
}

class FailingQrStorage implements QrStorage {
  @override
  Future<String> savePng({
    required Uint8List bytes,
    required String fileName,
  }) {
    throw StateError('Test save failure');
  }
}

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

  Future<Box> createTestBox() async {
    final boxId = await BoxRepository(database).createBox(
      'TM:BOX:12345678-1234-4123-8123-123456789abc',
    );

    final box = await BoxRepository(database).getBoxById(
      boxId,
    );

    return box!;
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required Box box,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BoxDetailPage(
          box: box,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows box details',
    (tester) async {
      final box = await createTestBox();

      await pumpPage(
        tester,
        box: box,
      );

      expect(
        find.text('Box Details'),
        findsOneWidget,
      );

      expect(
        find.text(
          'TM:BOX:12345678-1234-4123-8123-123456789abc',
        ),
        findsOneWidget,
      );

      expect(
        find.text('Box ID'),
        findsOneWidget,
      );

      expect(
        find.text(box.id.toString()),
        findsOneWidget,
      );

      expect(
        find.text('Created'),
        findsOneWidget,
      );

      expect(
        find.text('Updated'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows QR code',
    (tester) async {
      final box = await createTestBox();

      await pumpPage(
        tester,
        box: box,
      );

      expect(
        find.byKey(
          const Key('box-qr-code'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key('box-qr-image'),
        ),
        findsOneWidget,
      );

      expect(
        find.byType(QrImageView),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'QR code receives box QR ID',
    (tester) async {
      final box = await createTestBox();

      await pumpPage(
        tester,
        box: box,
      );

      final boxQrCode = tester.widget<BoxQrCode>(
        find.byKey(
          const Key('box-qr-code'),
        ),
      );

      expect(
        boxQrCode.qrId,
        box.qrId,
      );
    },
  );

  testWidgets(
    'back navigation returns to previous page',
    (tester) async {
      final box = await createTestBox();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  key: const Key('open-box-detail-button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BoxDetailPage(
                          box: box,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Box'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const Key('open-box-detail-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Box Details'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        find.text('Box Details'),
        findsNothing,
      );

      expect(
        find.text('Open Box'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows QR save button',
    (tester) async {
      final box = await createTestBox();

      await pumpPage(
        tester,
        box: box,
      );

      expect(
        find.byKey(
          const Key('save-qr-button'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows error when QR generation fails',
    (tester) async {
      final box = await createTestBox();

      await tester.pumpWidget(
        MaterialApp(
          home: BoxDetailPage(
            box: box,
            qrExporter: FailingQrExporter(),
            qrStorage: FakeQrStorage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('save-qr-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Failed to save QR code'),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key('qr-save-error'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows QR save button',
    (tester) async {
      final box = await createTestBox();

      await pumpPage(
        tester,
        box: box,
      );

      expect(
        find.byKey(
          const Key('save-qr-button'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'saves QR code as PNG',
    (tester) async {
      final box = await createTestBox();

      final exporter = FakeQrExporter();
      final storage = FakeQrStorage();

      await tester.pumpWidget(
        MaterialApp(
          home: BoxDetailPage(
            box: box,
            qrExporter: exporter,
            qrStorage: storage,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('save-qr-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        exporter.exportedQrId,
        box.qrId,
      );

      expect(
        storage.savedBytes,
        isNotNull,
      );

      expect(
        storage.savedBytes,
        isNotEmpty,
      );

      expect(
        storage.savedFileName,
        buildBoxQrFileName(box.qrId),
      );

      expect(
        find.text('QR code saved'),
        findsOneWidget,
      );

      expect(
        find.text('Failed to save QR code'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'shows error when saving QR code fails',
    (tester) async {
      final box = await createTestBox();

      await tester.pumpWidget(
        MaterialApp(
          home: BoxDetailPage(
            box: box,
            qrExporter: FakeQrExporter(),
            qrStorage: FailingQrStorage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('save-qr-button'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Failed to save QR code'),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const Key('qr-save-error'),
        ),
        findsOneWidget,
      );
    },
  );
}