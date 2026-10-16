import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const double minimumAnimalLabelWidthMm = 80;
const double maximumAnimalLabelWidthMm = 200;
const double defaultAnimalLabelWidthMm = 120;

enum AnimalProfilePdfKind { label, handover }

class AnimalProfilePdfOptions {
  const AnimalProfilePdfOptions({
    required this.kind,
    this.labelWidthMm = defaultAnimalLabelWidthMm,
    this.includeGallery = false,
  });

  final AnimalProfilePdfKind kind;
  final double labelWidthMm;
  final bool includeGallery;
}

class AnimalProfilePdfField {
  const AnimalProfilePdfField(this.label, this.value);

  final String label;
  final String value;
}

class AnimalProfilePdfEntry {
  const AnimalProfilePdfEntry(this.date, {this.value, this.notes});

  final String date;
  final String? value;
  final String? notes;
}

class AnimalProfilePdfData {
  const AnimalProfilePdfData({
    required this.name,
    required this.fields,
    this.labelFields,
    required this.feedingTitle,
    required this.sheddingTitle,
    required this.weightTitle,
    required this.galleryTitle,
    this.primaryPicture,
    this.galleryPictures = const [],
    this.feedings = const [],
    this.shedding = const [],
    this.weights = const [],
  });

  final String name;
  final List<AnimalProfilePdfField> fields;
  final List<AnimalProfilePdfField>? labelFields;
  final Uint8List? primaryPicture;
  final List<Uint8List> galleryPictures;
  final String feedingTitle;
  final String sheddingTitle;
  final String weightTitle;
  final String galleryTitle;
  final List<AnimalProfilePdfEntry> feedings;
  final List<AnimalProfilePdfEntry> shedding;
  final List<AnimalProfilePdfEntry> weights;
}

abstract class AnimalProfilePdfExporter {
  Future<Uint8List> export(
    AnimalProfilePdfData data,
    AnimalProfilePdfOptions options,
  );
}

class AnimalProfilePdfExportService implements AnimalProfilePdfExporter {
  const AnimalProfilePdfExportService();

  @override
  Future<Uint8List> export(
    AnimalProfilePdfData data,
    AnimalProfilePdfOptions options,
  ) async {
    if (options.kind == AnimalProfilePdfKind.label &&
        (!options.labelWidthMm.isFinite ||
            options.labelWidthMm < minimumAnimalLabelWidthMm ||
            options.labelWidthMm > maximumAnimalLabelWidthMm)) {
      throw RangeError.value(options.labelWidthMm, 'labelWidthMm');
    }
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final document = pw.Document(
      title: 'TerraManager ${data.name}',
      author: 'TerraManager',
      creator: 'TerraManager',
    );
    final primary = _pdfImage(data.primaryPicture);
    if (options.kind == AnimalProfilePdfKind.label) {
      _addLabel(document, data, options.labelWidthMm, font, primary);
    } else {
      _addHandover(document, data, font, primary, options.includeGallery);
    }
    return document.save();
  }

  static pw.MemoryImage? _pdfImage(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final oriented = img.bakeOrientation(decoded);
    final resized = oriented.width > 1400 || oriented.height > 1400
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? 1400 : null,
            height: oriented.height > oriented.width ? 1400 : null,
          )
        : oriented;
    return pw.MemoryImage(
      Uint8List.fromList(img.encodeJpg(resized, quality: 85)),
    );
  }

  static void _addLabel(
    pw.Document document,
    AnimalProfilePdfData data,
    double widthMm,
    pw.Font font,
    pw.MemoryImage? primary,
  ) {
    const marginMm = 5.0;
    final imageWidthMm = primary == null ? 0.0 : math.min(40, widthMm * 0.30);
    final labelFields = (data.labelFields ?? data.fields)
        .where((field) => field.value != data.name)
        .toList(growable: false);
    final textWidthMm =
        widthMm - (marginMm * 2) - imageWidthMm - (primary == null ? 0 : 4);
    final charactersPerLine = math.max(10, (textWidthMm * 2.835 / 5.2).floor());
    int lines(String value) => value
        .split('\n')
        .fold(
          0,
          (sum, line) =>
              sum + math.max(1, (line.length / charactersPerLine).ceil()),
        );
    final textHeightMm =
        6 +
        lines(data.name) * 5 +
        labelFields.fold<double>(
          0,
          (sum, field) =>
              sum + 1.5 + lines('${field.label}: ${field.value}') * 4,
        );
    final heightMm = math.max(imageWidthMm + 10, textHeightMm + 12);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          widthMm * PdfPageFormat.mm,
          heightMm * PdfPageFormat.mm,
          marginAll: marginMm * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (primary != null) ...[
              pw.Container(
                width: imageWidthMm * PdfPageFormat.mm,
                height: imageWidthMm * PdfPageFormat.mm,
                child: pw.Image(primary, fit: pw.BoxFit.cover),
              ),
              pw.SizedBox(width: 4 * PdfPageFormat.mm),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.name,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2 * PdfPageFormat.mm),
                  ...labelFields.map(
                    (field) => pw.Padding(
                      padding: pw.EdgeInsets.only(
                        bottom: 1.5 * PdfPageFormat.mm,
                      ),
                      child: pw.Text(
                        '${field.label}: ${field.value}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _addHandover(
    pw.Document document,
    AnimalProfilePdfData data,
    pw.Font font,
    pw.MemoryImage? primary,
    bool includeGallery,
  ) {
    final headerFields = data.fields.take(5).toList();
    final remainingFields = data.fields.skip(5).toList();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(12 * PdfPageFormat.mm),
        maxPages: 1000,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (primary != null) ...[
                pw.Container(
                  width: 48 * PdfPageFormat.mm,
                  height: 48 * PdfPageFormat.mm,
                  child: pw.Image(primary, fit: pw.BoxFit.cover),
                ),
                pw.SizedBox(width: 6 * PdfPageFormat.mm),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      data.name,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3 * PdfPageFormat.mm),
                    ...headerFields.expand(_field),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5 * PdfPageFormat.mm),
          ...remainingFields.expand(_field),
          ..._history(data.feedingTitle, data.feedings),
          ..._history(data.sheddingTitle, data.shedding),
          ..._history(data.weightTitle, data.weights),
          if (includeGallery) ..._gallery(data),
        ],
      ),
    );
  }

  static Iterable<pw.Widget> _field(AnimalProfilePdfField field) sync* {
    var first = true;
    for (final chunk in _chunks(field.value, 300)) {
      yield pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 2 * PdfPageFormat.mm),
        child: pw.Text(
          first ? '${field.label}: $chunk' : chunk,
          style: const pw.TextStyle(fontSize: 10),
        ),
      );
      first = false;
    }
  }

  static Iterable<pw.Widget> _gallery(AnimalProfilePdfData data) sync* {
    for (var index = 0; index < data.galleryPictures.length; index++) {
      final picture = _pdfImage(data.galleryPictures[index]);
      if (picture == null) continue;
      yield pw.NewPage(freeSpace: 130 * PdfPageFormat.mm);
      yield _heading(
        '${data.galleryTitle} ${index + 1}/${data.galleryPictures.length}',
      );
      yield pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 6 * PdfPageFormat.mm),
        child: pw.Container(
          height: 100 * PdfPageFormat.mm,
          alignment: pw.Alignment.centerLeft,
          child: pw.Image(picture, fit: pw.BoxFit.contain),
        ),
      );
    }
  }

  static pw.Widget _heading(String title) => pw.Padding(
    padding: pw.EdgeInsets.only(
      top: 6 * PdfPageFormat.mm,
      bottom: 3 * PdfPageFormat.mm,
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
  );

  static List<pw.Widget> _history(
    String title,
    List<AnimalProfilePdfEntry> entries,
  ) {
    if (entries.isEmpty) return const [];
    return [
      pw.NewPage(freeSpace: 20 * PdfPageFormat.mm),
      _heading(title),
      for (final entry in entries) ...[
        pw.Text(
          [
            entry.date,
            if (entry.value?.trim().isNotEmpty == true) entry.value!,
          ].join(' · '),
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (entry.notes?.trim().isNotEmpty == true)
          for (final chunk in _chunks(entry.notes!, 350))
            pw.Padding(
              padding: pw.EdgeInsets.only(left: 3 * PdfPageFormat.mm),
              child: pw.Text(chunk, style: const pw.TextStyle(fontSize: 9)),
            ),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
      ],
    ];
  }

  static Iterable<String> _chunks(String value, int maxLength) sync* {
    final words = value.split(RegExp(r'\s+'));
    var current = '';
    for (final word in words) {
      if (current.isNotEmpty && current.length + word.length + 1 > maxLength) {
        yield current;
        current = '';
      }
      if (word.length > maxLength) {
        if (current.isNotEmpty) {
          yield current;
          current = '';
        }
        for (var start = 0; start < word.length; start += maxLength) {
          yield word.substring(start, math.min(word.length, start + maxLength));
        }
      } else {
        current = current.isEmpty ? word : '$current $word';
      }
    }
    if (current.isNotEmpty) yield current;
  }
}
