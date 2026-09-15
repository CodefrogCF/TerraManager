import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/qr/qr_export_service.dart';
import 'package:terramanager/core/qr/qr_file_name.dart';
import 'package:terramanager/core/qr/qr_storage_service.dart';
import 'package:terramanager/features/settings/application/box_qr_batch_export_service.dart';

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
  final Map<String, Uint8List> files = {};
  final List<String> attempts = [];
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
    files[fileName] = Uint8List.fromList(bytes);
    return '$fileName.png';
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

  Future<Box> createBox(String qrId, {String? name}) async {
    final id = await boxes.createBox(qrId, name: name);
    return (await boxes.getBoxById(id))!;
  }

  test(
    'exports each selected existing QR ID with a unique safe filename',
    () async {
      final first = await createBox(
        'TM:BOX:11111111-1111-4111-8111-111111111111',
        name: 'First',
      );
      final second = await createBox(
        'TM:BOX:22222222-2222-4222-8222-222222222222',
      );
      final exporter = _RecordingQrExporter();
      final storage = _RecordingQrStorage();
      final service = BoxQrBatchExportService(
        qrExporter: exporter,
        qrStorage: storage,
      );

      final result = await service.exportBoxes([first, second, first]);

      expect(result.isCompleteSuccess, isTrue);
      expect(result.succeeded.map((box) => box.id), [first.id, second.id]);
      expect(result.failures, isEmpty);
      expect(exporter.qrIds, [first.qrId, second.qrId]);

      final firstFileName = buildBoxQrFileName(first.qrId);
      final secondFileName = buildBoxQrFileName(second.qrId);
      expect(firstFileName, isNot(secondFileName));
      expect(storage.files.keys, containsAll([firstFileName, secondFileName]));
      expect(utf8.decode(storage.files[firstFileName]!), first.qrId);
      expect(utf8.decode(storage.files[secondFileName]!), second.qrId);
    },
  );

  test(
    'records one failure and continues saving the remaining Boxes',
    () async {
      final first = await createBox(
        'TM:BOX:33333333-3333-4333-8333-333333333333',
      );
      final failing = await createBox(
        'TM:BOX:44444444-4444-4444-8444-444444444444',
      );
      final last = await createBox(
        'TM:BOX:55555555-5555-4555-8555-555555555555',
      );
      final failingFileName = buildBoxQrFileName(failing.qrId);
      final exporter = _RecordingQrExporter();
      final storage = _RecordingQrStorage(failingFileNames: {failingFileName});
      final service = BoxQrBatchExportService(
        qrExporter: exporter,
        qrStorage: storage,
      );

      final result = await service.exportBoxes([first, failing, last]);

      expect(result.isCompleteSuccess, isFalse);
      expect(result.isCompleteFailure, isFalse);
      expect(result.succeeded.map((box) => box.id), [first.id, last.id]);
      expect(result.failures.single.box.id, failing.id);
      expect(exporter.qrIds, [first.qrId, failing.qrId, last.qrId]);
      expect(storage.attempts, hasLength(3));
      expect(storage.files, hasLength(2));
    },
  );

  test(
    'rejects an empty selection before generating or saving files',
    () async {
      final exporter = _RecordingQrExporter();
      final storage = _RecordingQrStorage();
      final service = BoxQrBatchExportService(
        qrExporter: exporter,
        qrStorage: storage,
      );

      await expectLater(service.exportBoxes(const []), throwsArgumentError);

      expect(exporter.qrIds, isEmpty);
      expect(storage.attempts, isEmpty);
    },
  );
}
