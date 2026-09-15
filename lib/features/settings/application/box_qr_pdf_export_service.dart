import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/app_database.dart';

const double minimumBoxQrPdfSizeMm = 6;
const double maximumBoxQrPdfSizeMm = 20;
const double defaultBoxQrPdfSizeMm = 15;

class BoxQrPdfPlacement {
  final int itemIndex;
  final int pageIndex;
  final int row;
  final int column;
  final double leftMm;
  final double topMm;

  const BoxQrPdfPlacement({
    required this.itemIndex,
    required this.pageIndex,
    required this.row,
    required this.column,
    required this.leftMm,
    required this.topMm,
  });
}

class BoxQrPdfLayout {
  static const double pageWidthMm = 210;
  static const double pageHeightMm = 297;
  static const double marginMm = 10;
  static const double spacingMm = 4;
  static const double labelHeightMm = 4;

  final double qrSizeMm;

  BoxQrPdfLayout(this.qrSizeMm) {
    if (!qrSizeMm.isFinite ||
        qrSizeMm < minimumBoxQrPdfSizeMm ||
        qrSizeMm > maximumBoxQrPdfSizeMm) {
      throw RangeError(
        'qrSizeMm must be between $minimumBoxQrPdfSizeMm and '
        '$maximumBoxQrPdfSizeMm millimetres.',
      );
    }
  }

  double get cellWidthMm => qrSizeMm;
  double get cellHeightMm => qrSizeMm + labelHeightMm;
  double get quietZoneMm => math.max(0.75, qrSizeMm * 0.08);
  double get qrSymbolSizeMm => qrSizeMm - (quietZoneMm * 2);
  double get availableWidthMm => pageWidthMm - (marginMm * 2);
  double get availableHeightMm => pageHeightMm - (marginMm * 2);

  int get columnCount =>
      ((availableWidthMm + spacingMm) / (cellWidthMm + spacingMm)).floor();

  int get rowCount =>
      ((availableHeightMm + spacingMm) / (cellHeightMm + spacingMm)).floor();

  int get itemsPerPage => columnCount * rowCount;

  int pageCountFor(int itemCount) {
    if (itemCount < 0) {
      throw RangeError.value(itemCount, 'itemCount');
    }
    if (itemCount == 0) {
      return 0;
    }
    return (itemCount / itemsPerPage).ceil();
  }

  List<BoxQrPdfPlacement> placementsFor(int itemCount) {
    if (itemCount < 0) {
      throw RangeError.value(itemCount, 'itemCount');
    }

    return List<BoxQrPdfPlacement>.generate(itemCount, (itemIndex) {
      final pageItemIndex = itemIndex % itemsPerPage;
      final row = pageItemIndex ~/ columnCount;
      final column = pageItemIndex % columnCount;

      return BoxQrPdfPlacement(
        itemIndex: itemIndex,
        pageIndex: itemIndex ~/ itemsPerPage,
        row: row,
        column: column,
        leftMm: marginMm + (column * (cellWidthMm + spacingMm)),
        topMm: marginMm + (row * (cellHeightMm + spacingMm)),
      );
    }, growable: false);
  }
}

class BoxQrPdfItem {
  final int boxId;
  final String qrPayload;
  final String label;

  const BoxQrPdfItem({
    required this.boxId,
    required this.qrPayload,
    required this.label,
  });
}

abstract class BoxQrPdfExporter {
  Future<Uint8List> exportPdf(Iterable<Box> boxes, {required double qrSizeMm});
}

class BoxQrPdfExportService implements BoxQrPdfExporter {
  const BoxQrPdfExportService();

  List<BoxQrPdfItem> createItems(
    Iterable<Box> boxes, {
    required double qrSizeMm,
  }) {
    final uniqueBoxes = <int, Box>{for (final box in boxes) box.id: box}.values;
    final maximumLabelLength = math.max(8, (qrSizeMm * 1.3).floor());

    return uniqueBoxes
        .map(
          (box) => BoxQrPdfItem(
            boxId: box.id,
            qrPayload: box.qrId,
            label: _boxLabel(box, maximumLabelLength),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Uint8List> exportPdf(
    Iterable<Box> boxes, {
    required double qrSizeMm,
  }) async {
    final layout = BoxQrPdfLayout(qrSizeMm);
    final items = createItems(boxes, qrSizeMm: qrSizeMm);

    if (items.isEmpty) {
      throw ArgumentError.value(boxes, 'boxes', 'Select at least one Box.');
    }

    final placements = layout.placementsFor(items.length);
    final document = pw.Document(
      title: 'TerraManager Box QR Codes',
      author: 'TerraManager',
      creator: 'TerraManager',
      subject: 'Printable Box QR codes',
    );

    for (
      var pageIndex = 0;
      pageIndex < layout.pageCountFor(items.length);
      pageIndex++
    ) {
      final pagePlacements = placements
          .where((placement) => placement.pageIndex == pageIndex)
          .toList(growable: false);

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              for (final placement in pagePlacements)
                pw.Positioned(
                  left: placement.leftMm * PdfPageFormat.mm,
                  top: placement.topMm * PdfPageFormat.mm,
                  child: _buildItem(items[placement.itemIndex], layout: layout),
                ),
            ],
          ),
        ),
      );
    }

    return document.save();
  }

  pw.Widget _buildItem(BoxQrPdfItem item, {required BoxQrPdfLayout layout}) {
    final qrSize = layout.qrSizeMm * PdfPageFormat.mm;
    final labelHeight = BoxQrPdfLayout.labelHeightMm * PdfPageFormat.mm;
    final quietZone = layout.quietZoneMm * PdfPageFormat.mm;

    return pw.SizedBox(
      width: qrSize,
      height: layout.cellHeightMm * PdfPageFormat.mm,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: item.qrPayload,
            width: qrSize,
            height: qrSize,
            padding: pw.EdgeInsets.all(quietZone),
            backgroundColor: PdfColors.white,
            drawText: false,
          ),
          pw.SizedBox(
            width: qrSize,
            height: labelHeight,
            child: pw.Center(
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                child: pw.Text(
                  item.label,
                  maxLines: 1,
                  style: const pw.TextStyle(fontSize: 5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _boxLabel(Box box, int maximumLength) {
    final boxNumber = '#${box.id}';
    final name = box.name?.trim();

    if (name == null ||
        name.isEmpty ||
        name.runes.any((character) => character > 255)) {
      return 'Box ${box.id}';
    }

    final suffix = ' · $boxNumber';
    final availableNameLength = maximumLength - suffix.length;
    if (availableNameLength < 4) {
      return boxNumber;
    }

    final shortName = name.length <= availableNameLength
        ? name
        : '${name.substring(0, availableNameLength - 3)}...';
    return '$shortName$suffix';
  }
}
