import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/qr/qr_export_service.dart';
import 'package:terramanager/core/qr/qr_file_name.dart';
import 'package:terramanager/core/qr/qr_storage_service.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';

class _RecordingQrExporter implements QrExporter {
  final List<String> qrIds = [];

  @override
  Future<Uint8List> exportPng({
    required String qrId,
    double size = 1024,
  }) async {
    qrIds.add(qrId);
    return Uint8List.fromList(utf8.encode(qrId));
  }
}

class _RecordingQrStorage implements QrStorage {
  final List<String> attempts = [];
  final Map<String, Uint8List> saved = {};
  final Set<String> failingFileNames;

  _RecordingQrStorage({this.failingFileNames = const {}});

  @override
  Future<String> savePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    attempts.add(fileName);
    if (failingFileNames.contains(fileName)) {
      throw StateError('Saving failed');
    }
    saved[fileName] = Uint8List.fromList(bytes);
    return '$fileName.png';
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
    required QrExporter exporter,
    required QrStorage storage,
  }) async {
    final controller = AppSettingsController();
    await controller.load();
    await tester.pumpWidget(
      AppSettingsScope(
        controller: controller,
        child: MaterialApp(
          home: SettingsPage(
            database: database,
            qrExporter: exporter,
            qrStorage: storage,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSelection(WidgetTester tester) async {
    final settingsScrollable = find.descendant(
      of: find.byType(SettingsPage),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-box-qr-codes-button')),
      300,
      scrollable: settingsScrollable.first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-box-qr-codes-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel saves nothing and confirmation exports every Box', (
    tester,
  ) async {
    final active = await createBox(
      'TM:BOX:11111111-1111-4111-8111-111111111111',
      name: 'Main Rack',
    );
    final archived = await createBox(
      'TM:BOX:22222222-2222-4222-8222-222222222222',
      name: 'Old Rack',
    );
    await boxes.archiveBox(
      boxId: archived.id,
      reason: BoxArchiveReason.replaced,
      archivedAt: DateTime(2026, 9, 15),
    );
    final exporter = _RecordingQrExporter();
    final storage = _RecordingQrStorage();
    await pumpSettings(tester, exporter: exporter, storage: storage);

    await openSelection(tester);
    expect(find.text('Active Boxes'), findsOneWidget);
    expect(find.text('Archived Boxes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-box-qr-export-button')));
    await tester.pumpAndSettle();
    expect(exporter.qrIds, isEmpty);
    expect(storage.attempts, isEmpty);

    await openSelection(tester);
    await tester.tap(find.byKey(const Key('confirm-box-qr-export-button')));
    await tester.pumpAndSettle();

    expect(exporter.qrIds, [active.qrId, archived.qrId]);
    expect(storage.attempts, [
      buildBoxQrFileName(active.qrId),
      buildBoxQrFileName(archived.qrId),
    ]);
    expect(storage.saved, hasLength(2));
    expect(find.text('2 Box QR codes saved'), findsOneWidget);
  });

  testWidgets('partial failure reports the Box and preserves other exports', (
    tester,
  ) async {
    final first = await createBox(
      'TM:BOX:33333333-3333-4333-8333-333333333333',
      name: 'First',
    );
    final failing = await createBox(
      'TM:BOX:44444444-4444-4444-8444-444444444444',
      name: 'Failed Rack',
    );
    final last = await createBox(
      'TM:BOX:55555555-5555-4555-8555-555555555555',
      name: 'Last',
    );
    final exporter = _RecordingQrExporter();
    final storage = _RecordingQrStorage(
      failingFileNames: {buildBoxQrFileName(failing.qrId)},
    );
    await pumpSettings(tester, exporter: exporter, storage: storage);

    await openSelection(tester);
    await tester.tap(find.byKey(const Key('confirm-box-qr-export-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('box-qr-export-result-dialog')),
      findsOneWidget,
    );
    expect(find.text('2 saved; 1 failed.'), findsOneWidget);
    expect(
      find.textContaining('Failed Rack · Box ${failing.id}'),
      findsOneWidget,
    );
    expect(exporter.qrIds, [first.qrId, failing.qrId, last.qrId]);
    expect(storage.attempts, hasLength(3));
    expect(storage.saved, hasLength(2));
  });

  testWidgets('empty database starts no export', (tester) async {
    final exporter = _RecordingQrExporter();
    final storage = _RecordingQrStorage();
    await pumpSettings(tester, exporter: exporter, storage: storage);

    await openSelection(tester);

    expect(find.byKey(const Key('box-qr-selection-dialog')), findsNothing);
    expect(find.text('No boxes available'), findsOneWidget);
    expect(exporter.qrIds, isEmpty);
    expect(storage.attempts, isEmpty);
  });
}
