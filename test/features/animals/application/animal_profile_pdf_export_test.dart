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
        'humidityMin': 40,
        'humidityMax': 60,
        'originHabitat': '',
        'notes': notes,
      },
      category: locale.languageCode == 'de' ? 'Reptilien' : 'Reptiles',
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
}
