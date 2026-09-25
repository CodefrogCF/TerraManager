import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/core/qr/qr_export_service.dart';
import 'package:terramanager/features/settings/presentation/box_qr_selection_dialog.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_box_qr_export.dart';

const firstQr = 'TM:BOX:12345678-1234-4123-8123-123456789abc';
const secondQr = 'TM:BOX:12345678-1234-4123-8123-123456789abd';

class _QrExporter implements QrExporter {
  final payloads = <String>[];

  @override
  Future<Uint8List> exportPng({
    required String qrId,
    double size = 1024,
  }) async {
    payloads.add(qrId);
    return Uint8List.fromList(qrId.codeUnits);
  }
}

class _Downloader implements SharedBoxQrDownloader {
  final files = <String, Uint8List>{};
  final types = <String, String>{};
  bool succeed = true;

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (succeed) {
      files[fileName] = bytes;
      types[fileName] = mimeType;
    }
    return succeed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final active = SharedBoxQrRecord.fromJson({
    'id': 1,
    'qrId': firstQr,
    'name': 'Terrarium',
    'status': 'active',
  });
  final archived = SharedBoxQrRecord.fromJson({
    'id': 2,
    'qrId': secondQr,
    'status': 'archived',
  });

  test('selection includes archived Boxes and excludes unchecked Boxes', () {
    expect(active.displayLabel, 'Terrarium · Box 1');
    expect(archived.displayLabel, 'Box 2');
    expect(selectSharedBoxQrRecords([active, archived], {2}), [archived]);
    expect(
      () => SharedBoxQrRecord.fromJson({
        'id': 3,
        'qrId': 'not-a-box-qr',
        'status': 'active',
      }),
      throwsFormatException,
    );
  });

  test(
    'individual export downloads only selected permanent QR identifiers',
    () async {
      final qr = _QrExporter();
      final downloader = _Downloader();
      final service = SharedBoxQrExportService(
        qrExporter: qr,
        downloader: downloader,
      );

      final result = await service.export(BoxQrExportKind.images, [
        active,
        active,
      ]);
      expect(result.saved, 1);
      expect(result.failed, 0);
      expect(qr.payloads, [firstQr]);
      expect(
        downloader.files.keys.single,
        'terramanager_TM_BOX_12345678-1234-4123-8123-123456789abc.png',
      );
      expect(downloader.types.values.single, 'image/png');
    },
  );

  test('ZIP contains both selected PNGs with stable filenames', () async {
    final downloader = _Downloader();
    final service = SharedBoxQrExportService(
      qrExporter: _QrExporter(),
      downloader: downloader,
    );

    final result = await service.export(BoxQrExportKind.zip, [
      active,
      archived,
    ]);
    expect(result.saved, 2);
    final zip = downloader.files['TerraManager_Box_QR_Codes.zip']!;
    expect(
      downloader.types['TerraManager_Box_QR_Codes.zip'],
      'application/zip',
    );
    final entries = ZipDecoder().decodeBytes(zip);
    expect(entries.files.map((file) => file.name), [
      'terramanager_TM_BOX_12345678-1234-4123-8123-123456789abc.png',
      'terramanager_TM_BOX_12345678-1234-4123-8123-123456789abd.png',
    ]);
  });

  test('A4 PDF renders server-owned active and archived Boxes', () async {
    final downloader = _Downloader();
    final service = SharedBoxQrExportService(downloader: downloader);

    final result = await service.export(BoxQrExportKind.pdf, [
      active,
      archived,
    ], qrSizeMm: 12);
    expect(result.saved, 2);
    final pdf = downloader.files['TerraManager_Box_QR_Codes_A4.pdf']!;
    expect(pdf.length, greaterThan(1000));
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect(downloader.types.values.single, 'application/pdf');
  });

  test(
    'empty selection and failed browser download do not report success',
    () async {
      final downloader = _Downloader()..succeed = false;
      final service = SharedBoxQrExportService(
        qrExporter: _QrExporter(),
        downloader: downloader,
      );
      expect(
        () => service.export(BoxQrExportKind.zip, []),
        throwsArgumentError,
      );
      final result = await service.export(BoxQrExportKind.images, [active]);
      expect(result.saved, 0);
      expect(result.failed, 1);
    },
  );

  testWidgets('QR actions select archived Boxes before every export', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        if (request.url.path == '/api/v1/auth/session') {
          return http.Response(
            jsonEncode({
              'user': {'username': 'hagen', 'role': 'administrator'},
              'csrfToken': 'csrf',
              'expiresAt': '2026-09-26T00:00:00Z',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/boxes') {
          return http.Response(
            jsonEncode({
              'boxes': [
                {'id': 1, 'qrId': firstQr, 'status': 'active'},
                {'id': 2, 'qrId': secondQr, 'status': 'archived'},
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    await api.restoreSession();
    final downloader = _Downloader();
    final exporter = SharedBoxQrExportService(
      qrExporter: _QrExporter(),
      downloader: downloader,
    );
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SharedBoxQrExportSection(
            api: api,
            enabled: true,
            exporter: exporter,
          ),
        ),
      ),
    );

    for (final kind in BoxQrExportKind.values) {
      await tester.tap(find.byKey(Key('shared-box-qr-export-${kind.name}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('shared-box-qr-selection-dialog')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('shared-box-qr-checkbox-1')),
            )
            .value,
        true,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('shared-box-qr-checkbox-2')),
            )
            .value,
        true,
      );
      await tester.tap(find.byKey(const Key('shared-box-qr-checkbox-2')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('shared-box-qr-checkbox-2')),
            )
            .value,
        false,
      );
      await tester.tap(find.byKey(const Key('shared-box-qr-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('shared-box-qr-selection-dialog')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
    expect(downloader.files.length, 3);
  });
}
