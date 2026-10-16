import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:terramanager/features/animals/application/animal_profile_pdf_content.dart';
import 'package:terramanager/features/animals/application/animal_profile_pdf_export_service.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AnimalProfilePdfData profile(
    Locale locale, {
    Uint8List? picture,
    List<Uint8List> gallery = const [],
    int feedingCount = 1,
    String? longName,
    String? notes,
    String? subcategory,
    String? birthAccuracy,
    String? box,
  }) {
    final l10n = lookupAppLocalizations(locale);
    return AnimalProfilePdfContent.build(
      l10n: l10n,
      animal: {
        'commonName': longName ?? 'Corn snake',
        'latinName': 'Pantherophis guttatus',
        'birthDate': DateTime(2024, 5, 10),
        'tempMin': 24.5,
        'tempMax': 28,
        'nighttimeTemperatureMin': 20,
        'nighttimeTemperatureMax': 22,
        'humidityMin': 40,
        'humidityMax': 60,
        'originHabitat': '',
        'notes': notes,
      },
      category: locale.languageCode == 'de' ? 'Reptilien' : 'Reptiles',
      subcategory: subcategory,
      birthAccuracy: birthAccuracy,
      box: box,
      primaryPicture: picture,
      galleryPictures: gallery,
      feedings: [
        for (var i = 0; i < feedingCount; i++)
          {
            'fedAt': DateTime(2026, 10, 1).add(Duration(days: i)),
            'notes': 'Mouse ${i + 1}',
          },
      ],
      shedding: [
        {'shedAt': DateTime(2026, 9, 1), 'notes': 'Complete'},
      ],
      weights: [
        {'measuredAt': DateTime(2026, 9, 2), 'weightGrams': 123.5},
      ],
    );
  }

  String source(Uint8List bytes) => latin1.decode(bytes, allowInvalid: true);
  int pageCount(Uint8List bytes) =>
      RegExp(r'/Type\s*/Page\b').allMatches(source(bytes)).length;

  List<String> imageObjects(Uint8List bytes) => [
    for (final object in RegExp(
      r'\d+\s+\d+\s+obj\b([\s\S]*?)endobj',
    ).allMatches(source(bytes)))
      if (RegExp(r'/Subtype\s*/Image\b').hasMatch(object[1]!)) object[1]!,
  ];

  List<(int, int)> imageDimensions(Uint8List bytes) => [
    for (final object in imageObjects(bytes))
      (
        int.parse(RegExp(r'/Width\s+(\d+)').firstMatch(object)![1]!),
        int.parse(RegExp(r'/Height\s+(\d+)').firstMatch(object)![1]!),
      ),
  ];

  test('localizes populated data and omits empty optional fields', () {
    final english = profile(const Locale('en'));
    final german = profile(const Locale('de'));
    expect(english.fields.map((field) => field.label), contains('Common Name'));
    expect(german.fields.map((field) => field.label), contains('Name'));
    expect(german.fields.map((field) => field.label), contains('Geburtsdatum'));
    expect(
      english.fields.map((field) => field.label),
      isNot(contains('Origin / habitat')),
    );
    expect(
      english.fields.map((field) => field.label),
      isNot(contains('Notes')),
    );
    expect(english.feedings, hasLength(1));
    expect(english.shedding, hasLength(1));
    expect(english.weights.single.value, '123.5 g');
  });

  test('keeps complete A4 fields but shortens labels in both languages', () {
    for (final locale in [const Locale('de'), const Locale('en')]) {
      final l10n = lookupAppLocalizations(locale);
      final data = profile(
        locale,
        subcategory: 'Colubridae',
        birthAccuracy: 'Exact',
        box: 'Terrarium 1',
      );
      final completeFields = data.fields.map((field) => field.label);
      final labelFields = data.labelFields!;
      final labelCaptions = labelFields.map((field) => field.label);

      expect(completeFields, contains(l10n.latinName));
      expect(completeFields, contains(l10n.animalCategory));
      expect(completeFields, contains(l10n.animalSubcategory));
      expect(completeFields, contains(l10n.birthDateAccuracyLowercase));
      expect(completeFields, contains(l10n.box));
      expect(completeFields, contains(l10n.daytimeTemperature));
      expect(completeFields, contains(l10n.nighttimeTemperature));
      expect(labelCaptions, isNot(contains(l10n.animalCategory)));
      expect(labelCaptions, isNot(contains(l10n.animalSubcategory)));
      expect(labelCaptions, isNot(contains(l10n.birthDateAccuracyLowercase)));
      expect(labelCaptions, isNot(contains(l10n.box)));
      expect(labelCaptions, contains(l10n.birthDateLowercase));
      expect(
        labelCaptions,
        contains(locale.languageCode == 'de' ? 'Tag' : 'Day'),
      );
      expect(
        labelCaptions,
        contains(locale.languageCode == 'de' ? 'Nacht' : 'Night'),
      );
      expect(labelCaptions, isNot(contains(l10n.daytimeTemperature)));
      expect(labelCaptions, isNot(contains(l10n.nighttimeTemperature)));
      expect(
        labelFields
            .singleWhere((field) => field.value == 'Pantherophis guttatus')
            .label,
        isEmpty,
      );
    }
  });

  test(
    'exports a physical-width label with and without a primary picture',
    () async {
      final picture = Uint8List.fromList(
        img.encodePng(img.Image(width: 60, height: 40)),
      );
      final service = AnimalProfilePdfExportService();
      for (final bytes in [null, picture]) {
        final pdf = await service.export(
          profile(const Locale('de'), picture: bytes),
          const AnimalProfilePdfOptions(
            kind: AnimalProfilePdfKind.label,
            labelWidthMm: 120,
          ),
        );
        expect(latin1.decode(pdf.take(5).toList()), '%PDF-');
        expect(pageCount(pdf), 1);
        expect(source(pdf), contains('/MediaBox'));
        expect(source(pdf), contains(RegExp(r'340[.,]1|340[.,]2')));
        if (bytes != null) {
          expect(
            RegExp(r'/Subtype\s*/Image\b').allMatches(source(pdf)),
            isNotEmpty,
          );
        }
      }
    },
  );

  test('wraps long label values and paginates complete A4 histories', () async {
    final picture = Uint8List.fromList(
      img.encodePng(img.Image(width: 60, height: 40)),
    );
    final data = profile(
      const Locale('en'),
      picture: picture,
      gallery: [picture, picture],
      feedingCount: 110,
      longName: 'Long animal name ${'with readable details ' * 12}',
    );
    final service = AnimalProfilePdfExportService();
    final label = await service.export(
      data,
      const AnimalProfilePdfOptions(
        kind: AnimalProfilePdfKind.label,
        labelWidthMm: 80,
      ),
    );
    expect(pageCount(label), 1);
    final a4 = await service.export(
      data,
      const AnimalProfilePdfOptions(
        kind: AnimalProfilePdfKind.handover,
        includeGallery: true,
      ),
    );
    expect(pageCount(a4), greaterThan(1));
    expect(source(a4), contains('/MediaBox'));
    expect(
      RegExp(r'/Subtype\s*/Image\b').allMatches(source(a4)).length,
      greaterThanOrEqualTo(3),
    );
    final withoutGallery = await service.export(
      data,
      const AnimalProfilePdfOptions(kind: AnimalProfilePdfKind.handover),
    );
    expect(
      RegExp(r'/Subtype\s*/Image\b').allMatches(source(withoutGallery)).length,
      lessThan(RegExp(r'/Subtype\s*/Image\b').allMatches(source(a4)).length),
    );
  });

  test(
    'paginates long profile notes and A4 exports without pictures',
    () async {
      final data = profile(
        const Locale('de'),
        feedingCount: 0,
        notes: 'Eine ausführliche Beschreibung mit Umgebungsdaten. ' * 100,
      );
      final pdf = await const AnimalProfilePdfExportService().export(
        data,
        const AnimalProfilePdfOptions(kind: AnimalProfilePdfKind.handover),
      );
      expect(latin1.decode(pdf.take(5).toList()), '%PDF-');
      expect(pageCount(pdf), greaterThan(1));
      expect(RegExp(r'/Subtype\s*/Image\b').allMatches(source(pdf)), isEmpty);
    },
  );

  test('handles long unbroken names on the narrowest label', () async {
    final data = profile(
      const Locale('en'),
      feedingCount: 0,
      longName: 'PantherophisGuttatus' * 25,
    );
    final pdf = await const AnimalProfilePdfExportService().export(
      data,
      const AnimalProfilePdfOptions(
        kind: AnimalProfilePdfKind.label,
        labelWidthMm: minimumAnimalLabelWidthMm,
      ),
    );
    expect(pageCount(pdf), 1);
  });

  test('adds gallery pages with four pictures per page', () async {
    final picture = Uint8List.fromList(
      img.encodePng(img.Image(width: 60, height: 40)),
    );
    const service = AnimalProfilePdfExportService();
    for (final count in [0, 1, 3, 4, 5, 8, 9]) {
      final data = profile(
        const Locale('de'),
        picture: picture,
        gallery: List.filled(count, picture),
        feedingCount: 0,
      );
      final pdf = await service.export(
        data,
        const AnimalProfilePdfOptions(
          kind: AnimalProfilePdfKind.handover,
          includeGallery: true,
        ),
      );
      expect(pageCount(pdf), 1 + (count / 4).ceil(), reason: '$count pictures');
    }
  });

  test('keeps a fixed square label picture across label widths', () async {
    const service = AnimalProfilePdfExportService();
    for (final size in [(60, 40), (40, 60), (40, 40)]) {
      final picture = Uint8List.fromList(
        img.encodePng(img.Image(width: size.$1, height: size.$2)),
      );
      final data = profile(const Locale('en'), picture: picture);
      final labelImages = <String>[];
      for (final width in [80.0, 120.0, 200.0]) {
        final pdf = await service.export(
          data,
          AnimalProfilePdfOptions(
            kind: AnimalProfilePdfKind.label,
            labelWidthMm: width,
          ),
        );
        expect(imageDimensions(pdf), [(40, 40)]);
        labelImages.add(imageObjects(pdf).single);
      }
      expect(labelImages, everyElement(labelImages.first));
      final a4 = await service.export(
        data,
        const AnimalProfilePdfOptions(kind: AnimalProfilePdfKind.handover),
      );
      expect(imageDimensions(a4), [size]);
    }
  });

  test('skips invalid gallery pictures without adding empty pages', () async {
    final picture = Uint8List.fromList(
      img.encodePng(img.Image(width: 40, height: 60)),
    );
    for (final pictures in [
      [Uint8List(0)],
      [picture, Uint8List(0), picture, picture, picture],
    ]) {
      final pdf = await const AnimalProfilePdfExportService().export(
        profile(const Locale('en'), gallery: pictures, feedingCount: 0),
        const AnimalProfilePdfOptions(
          kind: AnimalProfilePdfKind.handover,
          includeGallery: true,
        ),
      );
      expect(pageCount(pdf), pictures.length == 1 ? 1 : 2);
    }
  });
}
