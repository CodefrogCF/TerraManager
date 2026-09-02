import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

abstract class QrPrinter {
  Future<void> printQrCode({required Uint8List pngBytes, required String qrId});
}

class QrPrintService implements QrPrinter {
  const QrPrintService();

  @override
  Future<void> printQrCode({
    required Uint8List pngBytes,
    required String qrId,
  }) async {
    final document = pw.Document();

    final image = pw.MemoryImage(pngBytes);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Image(image, width: 220, height: 220),
                pw.SizedBox(height: 16),
                pw.Text(qrId, textAlign: pw.TextAlign.center),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => document.save(),
      name: 'TerraManager QR Code',
    );
  }
}
