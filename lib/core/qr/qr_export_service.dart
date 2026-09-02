import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:qr_flutter/qr_flutter.dart';

abstract class QrExporter {
  Future<Uint8List> exportPng({required String qrId, double size = 1024});
}

class QrExportService implements QrExporter {
  const QrExportService();

  @override
  Future<Uint8List> exportPng({
    required String qrId,
    double size = 1024,
  }) async {
    final painter = QrPainter(
      data: qrId,
      version: QrVersions.auto,
      gapless: true,
    );

    final byteData = await painter.toImageData(
      size,
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw StateError(
        'QR export failed because PNG encoding returned no data.',
      );
    }

    return byteData.buffer.asUint8List();
  }
}
