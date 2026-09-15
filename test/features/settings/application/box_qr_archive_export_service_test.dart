import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/qr/qr_export_service.dart';
import 'package:terramanager/core/qr/qr_file_name.dart';
import 'package:terramanager/features/settings/application/box_qr_archive_export_service.dart';

class _QrExporter implements QrExporter {
  final List<String> qrIds = [];
  final String? failingQrId;

  _QrExporter({this.failingQrId});

  @override
  Future<Uint8List> exportPng({
    required String qrId,
    double size = 1024,
  }) async {
    qrIds.add(qrId);
    if (qrId == failingQrId) {
      throw StateError('QR generation failed');
    }
    return Uint8List.fromList(utf8.encode(qrId));
  }
}

void main() {
  late AppDatabase database;
  late BoxRepository boxes;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    boxes = BoxRepository(database);
  });

  tearDown(() => database.close());

  Future<Box> createBox(String qrId) async {
    final id = await boxes.createBox(qrId);
    return (await boxes.getBoxById(id))!;
  }

  test(
    'creates one uniquely named PNG with the exact payload per Box',
    () async {
      final first = await createBox(
        'TM:BOX:11111111-1111-4111-8111-111111111111',
      );
      final second = await createBox(
        'TM:BOX:22222222-2222-4222-8222-222222222222',
      );
      final exporter = _QrExporter();
      final service = BoxQrArchiveExportService(qrExporter: exporter);

      final bytes = await service.exportZip([first, second, first]);
      final archive = ZipDecoder().decodeBytes(bytes);

      expect(exporter.qrIds, [first.qrId, second.qrId]);
      expect(archive.files, hasLength(2));

      final files = {for (final file in archive.files) file.name: file};
      final firstName = '${buildBoxQrFileName(first.qrId)}.png';
      final secondName = '${buildBoxQrFileName(second.qrId)}.png';
      expect(firstName, isNot(secondName));
      expect(utf8.decode(files[firstName]!.readBytes()!), first.qrId);
      expect(utf8.decode(files[secondName]!.readBytes()!), second.qrId);
    },
  );

  test('rejects the whole archive when one QR cannot be generated', () async {
    final first = await createBox(
      'TM:BOX:33333333-3333-4333-8333-333333333333',
    );
    final failing = await createBox(
      'TM:BOX:44444444-4444-4444-8444-444444444444',
    );
    final exporter = _QrExporter(failingQrId: failing.qrId);
    final service = BoxQrArchiveExportService(qrExporter: exporter);

    await expectLater(service.exportZip([first, failing]), throwsStateError);
    expect(exporter.qrIds, [first.qrId, failing.qrId]);
  });

  test('rejects an empty selection before QR generation', () async {
    final exporter = _QrExporter();
    final service = BoxQrArchiveExportService(qrExporter: exporter);

    await expectLater(service.exportZip(const []), throwsArgumentError);
    expect(exporter.qrIds, isEmpty);
  });
}
