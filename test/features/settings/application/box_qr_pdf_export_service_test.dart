import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/features/settings/application/box_qr_pdf_export_service.dart';
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/qrcode.dart';
import 'package:zxing_lib/zxing.dart';

Box box(int id, String qrId, {String? name}) {
  final timestamp = DateTime.utc(2026, 9, 15);
  return Box(
    id: id,
    qrId: qrId,
    status: BoxStatus.active,
    name: name,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

String decodePrintedQr(String payload, BoxQrPdfLayout layout) {
  const printDpi = 600;
  const pixelsPerMillimetre = printDpi / 25.4;
  final imageSize = (layout.qrSizeMm * pixelsPerMillimetre).round();
  final quietZone = (layout.quietZoneMm * pixelsPerMillimetre).round();
  final symbolSize = imageSize - (quietZone * 2);
  final raster = img.Image(width: imageSize, height: imageSize);
  img.fill(raster, color: img.ColorRgb8(255, 255, 255));

  final elements = pw.Barcode.qrCode().make(
    payload,
    width: symbolSize.toDouble(),
    height: symbolSize.toDouble(),
  );
  for (final element in elements) {
    if (element is! pw.BarcodeBar || !element.black) {
      continue;
    }
    img.fillRect(
      raster,
      x1: quietZone + element.left.floor(),
      y1: quietZone + element.top.floor(),
      x2: quietZone + element.right.ceil() - 1,
      y2: quietZone + element.bottom.ceil() - 1,
      color: img.ColorRgb8(0, 0, 0),
    );
  }

  final pixels = raster
      .convert(numChannels: 4)
      .getBytes(order: img.ChannelOrder.abgr)
      .buffer
      .asInt32List();
  final source = RGBLuminanceSource(raster.width, raster.height, pixels);
  final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
  return QRCodeReader().decode(bitmap).text;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('calculates unclipped A4 layouts for every supported preset', () {
    const expectedCapacity = {6: 380, 10: 195, 15: 120, 20: 80};

    for (final entry in expectedCapacity.entries) {
      final layout = BoxQrPdfLayout(entry.key.toDouble());
      final placements = layout.placementsFor(layout.itemsPerPage);

      expect(layout.itemsPerPage, entry.value, reason: '${entry.key} mm');
      expect(layout.pageCountFor(layout.itemsPerPage), 1);
      expect(placements, hasLength(entry.value));

      for (final placement in placements) {
        expect(placement.leftMm, greaterThanOrEqualTo(10));
        expect(placement.topMm, greaterThanOrEqualTo(10));
        expect(
          placement.leftMm + layout.cellWidthMm,
          lessThanOrEqualTo(BoxQrPdfLayout.pageWidthMm - 10),
        );
        expect(
          placement.topMm + layout.cellHeightMm,
          lessThanOrEqualTo(BoxQrPdfLayout.pageHeightMm - 10),
        );
      }
    }
  });

  test('automatically starts another A4 page after capacity', () {
    final layout = BoxQrPdfLayout(20);
    final placements = layout.placementsFor(layout.itemsPerPage + 1);
    final firstOnSecondPage = placements.last;

    expect(layout.pageCountFor(layout.itemsPerPage), 1);
    expect(layout.pageCountFor(layout.itemsPerPage + 1), 2);
    expect(firstOnSecondPage.pageIndex, 1);
    expect(firstOnSecondPage.row, 0);
    expect(firstOnSecondPage.column, 0);
    expect(firstOnSecondPage.leftMm, BoxQrPdfLayout.marginMm);
    expect(firstOnSecondPage.topMm, BoxQrPdfLayout.marginMm);
  });

  test('preserves payloads and distinguishes long duplicate names', () {
    const firstQr = 'TM:BOX:11111111-1111-4111-8111-111111111111';
    const secondQr = 'TM:BOX:22222222-2222-4222-8222-222222222222';
    final service = BoxQrPdfExportService();
    final items = service.createItems([
      box(1, firstQr, name: 'A very long duplicate enclosure name'),
      box(2, secondQr, name: 'A very long duplicate enclosure name'),
    ], qrSizeMm: 20);

    expect(items.map((item) => item.qrPayload), [firstQr, secondQr]);
    expect(items[0].label, isNot(items[1].label));
    expect(items[0].label, endsWith('#1'));
    expect(items[1].label, endsWith('#2'));
    expect(items.every((item) => item.label.length <= 26), isTrue);
  });

  test('creates a decodable vector QR at the smallest PDF size', () async {
    const qrId = 'TM:BOX:33333333-3333-4333-8333-333333333333';
    final layout = BoxQrPdfLayout(6);
    final barcode = pw.Barcode.qrCode();
    barcode.verify(qrId);
    final vectorElements = barcode
        .make(
          qrId,
          width: layout.qrSymbolSizeMm * PdfPageFormat.mm,
          height: layout.qrSymbolSizeMm * PdfPageFormat.mm,
        )
        .toList(growable: false);
    expect(vectorElements, isNotEmpty);
    expect(decodePrintedQr(qrId, layout), qrId);

    final bytes = await const BoxQrPdfExportService().exportPdf([
      box(3, qrId),
    ], qrSizeMm: 6);
    final header = latin1.decode(bytes.take(5).toList());
    final pdfSource = latin1.decode(bytes, allowInvalid: true);

    expect(header, '%PDF-');
    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdfSource), hasLength(1));
  });

  test('writes additional PDF pages automatically', () async {
    final boxes = List<Box>.generate(81, (index) {
      final boxNumber = index + 1;
      final suffix = boxNumber.toString().padLeft(12, '0');
      return box(boxNumber, 'TM:BOX:00000000-0000-4000-8000-$suffix');
    });

    final bytes = await const BoxQrPdfExportService().exportPdf(
      boxes,
      qrSizeMm: 20,
    );
    final pdfSource = latin1.decode(bytes, allowInvalid: true);

    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdfSource), hasLength(2));
  });

  test('rejects unsupported sizes and empty selections', () async {
    expect(() => BoxQrPdfLayout(5.9), throwsRangeError);
    expect(() => BoxQrPdfLayout(20.1), throwsRangeError);
    await expectLater(
      const BoxQrPdfExportService().exportPdf(const [], qrSizeMm: 10),
      throwsArgumentError,
    );
  });
}
