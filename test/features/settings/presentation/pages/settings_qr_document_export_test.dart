import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/settings/application/box_qr_archive_export_service.dart';
import 'package:terramanager/features/settings/application/box_qr_pdf_export_service.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/infrastructure/box_qr_document_storage_service.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';

class _RecordingArchiveExporter implements BoxQrArchiveExporter {
  final List<List<Box>> calls = [];

  @override
  Future<Uint8List> exportZip(Iterable<Box> boxes) async {
    calls.add(boxes.toList(growable: false));
    return Uint8List.fromList([1, 2, 3]);
  }
}

class _RecordingPdfExporter implements BoxQrPdfExporter {
  final List<List<Box>> calls = [];
  final List<double> sizes = [];
  final bool shouldFail;

  _RecordingPdfExporter({this.shouldFail = false});

  @override
  Future<Uint8List> exportPdf(
    Iterable<Box> boxes, {
    required double qrSizeMm,
  }) async {
    calls.add(boxes.toList(growable: false));
    sizes.add(qrSizeMm);
    if (shouldFail) {
      throw StateError('PDF generation failed');
    }
    return Uint8List.fromList([4, 5, 6]);
  }
}

class _RecordingDocumentStorage implements BoxQrDocumentStorage {
  final List<({Uint8List bytes, String fileName, BoxQrDocumentType type})>
  calls = [];
  final String? result;

  _RecordingDocumentStorage({this.result = 'saved'});

  @override
  Future<String?> saveDocument({
    required Uint8List bytes,
    required String fileName,
    required BoxQrDocumentType type,
  }) async {
    calls.add((bytes: bytes, fileName: fileName, type: type));
    return result;
  }
}

void main() {
  late AppDatabase database;
  late BoxRepository boxes;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.test(NativeDatabase.memory());
    boxes = BoxRepository(database);
  });

  tearDown(() => database.close());

  Future<Box> createBox(String qrId, {String? name}) async {
    final id = await boxes.createBox(qrId, name: name);
    return (await boxes.getBoxById(id))!;
  }

  Future<void> pumpSettings(
    WidgetTester tester, {
    required BoxQrArchiveExporter archiveExporter,
    required BoxQrPdfExporter pdfExporter,
    required BoxQrDocumentStorage storage,
  }) async {
    final controller = AppSettingsController();
    await controller.load();
    await tester.pumpWidget(
      AppSettingsScope(
        controller: controller,
        child: MaterialApp(
          home: SettingsPage(
            database: database,
            boxQrArchiveExporter: archiveExporter,
            boxQrPdfExporter: pdfExporter,
            boxQrDocumentStorage: storage,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAction(WidgetTester tester, Key key) async {
    final settingsScrollable = find.descendant(
      of: find.byType(SettingsPage),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: settingsScrollable.first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('all three settings actions reuse the Box selection workflow', (
    tester,
  ) async {
    await createBox(
      'TM:BOX:11111111-1111-4111-8111-111111111111',
      name: 'Active',
    );
    final archived = await createBox(
      'TM:BOX:22222222-2222-4222-8222-222222222222',
      name: 'Archived',
    );
    await boxes.archiveBox(
      boxId: archived.id,
      reason: BoxArchiveReason.replaced,
      archivedAt: DateTime(2026, 9, 15),
    );
    final archiveExporter = _RecordingArchiveExporter();
    final pdfExporter = _RecordingPdfExporter();
    final storage = _RecordingDocumentStorage();
    await pumpSettings(
      tester,
      archiveExporter: archiveExporter,
      pdfExporter: pdfExporter,
      storage: storage,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('save-box-qr-codes-button')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Choose the Boxes whose QR codes you want to save.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('box-qr-individual-zip-divider')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('box-qr-zip-pdf-divider')), findsOneWidget);

    for (final key in const [
      Key('save-box-qr-codes-button'),
      Key('save-box-qr-codes-zip-button'),
      Key('save-box-qr-codes-pdf-button'),
    ]) {
      await openAction(tester, key);
      expect(find.text('Active Boxes'), findsOneWidget);
      expect(find.text('Archived Boxes'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancel-box-qr-export-button')));
      await tester.pumpAndSettle();
    }

    expect(archiveExporter.calls, isEmpty);
    expect(pdfExporter.calls, isEmpty);
    expect(storage.calls, isEmpty);
  });

  testWidgets('ZIP saves only the selected existing QR codes', (tester) async {
    final first = await createBox(
      'TM:BOX:33333333-3333-4333-8333-333333333333',
    );
    final second = await createBox(
      'TM:BOX:44444444-4444-4444-8444-444444444444',
    );
    final archiveExporter = _RecordingArchiveExporter();
    final storage = _RecordingDocumentStorage();
    await pumpSettings(
      tester,
      archiveExporter: archiveExporter,
      pdfExporter: _RecordingPdfExporter(),
      storage: storage,
    );

    await openAction(tester, const Key('save-box-qr-codes-zip-button'));
    await tester.tap(find.byKey(Key('box-qr-selection-checkbox-${second.id}')));
    await tester.tap(find.byKey(const Key('confirm-box-qr-export-button')));
    await tester.pumpAndSettle();

    expect(archiveExporter.calls.single.map((box) => box.id), [first.id]);
    expect(storage.calls.single.fileName, boxQrZipFileName);
    expect(storage.calls.single.type, BoxQrDocumentType.zip);
    expect(find.text('ZIP with 1 Box QR code saved'), findsOneWidget);
  });

  testWidgets('PDF uses all selected Boxes and the selected millimetre size', (
    tester,
  ) async {
    final first = await createBox(
      'TM:BOX:55555555-5555-4555-8555-555555555555',
    );
    final second = await createBox(
      'TM:BOX:66666666-6666-4666-8666-666666666666',
    );
    final pdfExporter = _RecordingPdfExporter();
    final storage = _RecordingDocumentStorage();
    await pumpSettings(
      tester,
      archiveExporter: _RecordingArchiveExporter(),
      pdfExporter: pdfExporter,
      storage: storage,
    );

    await openAction(tester, const Key('save-box-qr-codes-pdf-button'));
    await tester.drag(
      find.byKey(const Key('box-qr-size-slider')),
      const Offset(-1000, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-box-qr-export-button')));
    await tester.pumpAndSettle();

    expect(pdfExporter.calls.single.map((box) => box.id), [
      first.id,
      second.id,
    ]);
    expect(pdfExporter.sizes.single, 6);
    expect(storage.calls.single.fileName, boxQrPdfFileName);
    expect(storage.calls.single.type, BoxQrDocumentType.pdf);
    expect(find.text('PDF with 2 Box QR codes saved'), findsOneWidget);
  });

  testWidgets('save-dialog cancellation reports no false success', (
    tester,
  ) async {
    await createBox('TM:BOX:77777777-7777-4777-8777-777777777777');
    final storage = _RecordingDocumentStorage(result: null);
    await pumpSettings(
      tester,
      archiveExporter: _RecordingArchiveExporter(),
      pdfExporter: _RecordingPdfExporter(),
      storage: storage,
    );

    await openAction(tester, const Key('save-box-qr-codes-zip-button'));
    await tester.tap(find.byKey(const Key('confirm-box-qr-export-button')));
    await tester.pumpAndSettle();

    expect(storage.calls, hasLength(1));
    expect(find.textContaining('ZIP with 1'), findsNothing);
  });

  testWidgets('PDF generation failure saves no incomplete file', (
    tester,
  ) async {
    await createBox('TM:BOX:88888888-8888-4888-8888-888888888888');
    final storage = _RecordingDocumentStorage();
    await pumpSettings(
      tester,
      archiveExporter: _RecordingArchiveExporter(),
      pdfExporter: _RecordingPdfExporter(shouldFail: true),
      storage: storage,
    );

    await openAction(tester, const Key('save-box-qr-codes-pdf-button'));
    await tester.tap(find.byKey(const Key('confirm-box-qr-export-button')));
    await tester.pumpAndSettle();

    expect(storage.calls, isEmpty);
    expect(
      find.text('Box QR codes could not be saved as a PDF file'),
      findsOneWidget,
    );
  });
}
