import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../core/database/app_database.dart';
import '../../../core/qr/qr_export_service.dart';
import '../../../core/qr/qr_file_name.dart';

abstract class BoxQrArchiveExporter {
  Future<Uint8List> exportZip(Iterable<Box> boxes);
}

class BoxQrArchiveExportService implements BoxQrArchiveExporter {
  final QrExporter qrExporter;

  const BoxQrArchiveExportService({required this.qrExporter});

  @override
  Future<Uint8List> exportZip(Iterable<Box> boxes) async {
    final uniqueBoxes = <int, Box>{for (final box in boxes) box.id: box}.values
        .toList(growable: false);

    if (uniqueBoxes.isEmpty) {
      throw ArgumentError.value(boxes, 'boxes', 'Select at least one Box.');
    }

    final archive = Archive();

    for (final box in uniqueBoxes) {
      final pngBytes = await qrExporter.exportPng(qrId: box.qrId);
      final fileName = '${buildBoxQrFileName(box.qrId)}.png';
      archive.add(ArchiveFile.bytes(fileName, pngBytes));
    }

    return ZipEncoder().encodeBytes(archive);
  }
}
