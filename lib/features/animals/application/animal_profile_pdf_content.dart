import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'animal_profile_pdf_export_service.dart';

/// Common, localized representation for local and Shared Care Animal records.
class AnimalProfilePdfContent {
  const AnimalProfilePdfContent._();

  static AnimalProfilePdfData build({
    required AppLocalizations l10n,
    required Map<String, dynamic> animal,
    required String category,
    String? subcategory,
    String? sex,
    String? birthAccuracy,
    String? box,
    String? archiveReason,
    Uint8List? primaryPicture,
    List<Uint8List> galleryPictures = const [],
    List<Map<String, dynamic>> feedings = const [],
    List<Map<String, dynamic>> shedding = const [],
    List<Map<String, dynamic>> weights = const [],
  }) {
    final locale = l10n.localeName;
    final numberFormat = NumberFormat('0.##', locale);
    String formatDate(DateTime date, {bool time = false}) {
      final year = date.year.toString();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final dayPart = locale.startsWith('de')
          ? '$day.$month.$year'
          : '$month/$day/$year';
      if (!time) return dayPart;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$dayPart $hour:$minute';
    }

    final fields = <AnimalProfilePdfField>[];
    void add(String label, Object? value) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        fields.add(AnimalProfilePdfField(label, text));
      }
    }

    String? temperature(Object? min, Object? max) {
      if (min is! num && max is! num) return null;
      final first = min is num ? numberFormat.format(min) : null;
      final last = max is num ? numberFormat.format(max) : null;
      if (first != null && last != null) {
        return l10n.temperatureRange(first, last);
      }
      return '${first ?? last} °C';
    }

    String? humidity(Object? min, Object? max) {
      if (min is! num && max is! num) return null;
      final first = min is num ? numberFormat.format(min) : null;
      final last = max is num ? numberFormat.format(max) : null;
      return first != null && last != null
          ? l10n.humidityRange(first, last)
          : '${first ?? last} %';
    }

    DateTime? readDate(Object? value) {
      if (value is DateTime) return value.toLocal();
      if (value is String) return DateTime.tryParse(value)?.toLocal();
      return null;
    }

    add(l10n.commonName, animal['commonName']);
    add(l10n.latinName, animal['latinName']);
    add(l10n.animalCategory, category);
    add(l10n.animalSubcategory, subcategory);
    add(l10n.sex, sex);
    if (readDate(animal['birthDate']) case final date?) {
      add(l10n.birthDateLowercase, formatDate(date));
    }
    add(l10n.birthDateAccuracyLowercase, birthAccuracy);
    add(l10n.box, box);
    add(
      l10n.daytimeTemperature,
      temperature(animal['tempMin'], animal['tempMax']),
    );
    add(
      l10n.nighttimeTemperature,
      temperature(
        animal['nighttimeTemperatureMin'] ?? animal['nighttimeTemperature'],
        animal['nighttimeTemperatureMax'] ?? animal['nighttimeTemperature'],
      ),
    );
    add(l10n.humidity, humidity(animal['humidityMin'], animal['humidityMax']));
    add(l10n.originHabitat, animal['originHabitat']);
    final labelFields = List<AnimalProfilePdfField>.of(fields);
    add(l10n.restOrDormancyPeriods, animal['restOrDormancyPeriods']);
    add(l10n.temperatureZones, animal['temperatureZones']);
    add(l10n.notes, animal['notes']);
    if (weights.isEmpty) add(l10n.weight, animal['weight']);
    add(l10n.sheddingNotes, animal['sheddingNotes']);
    if (animal['status'] == 'archived') {
      add(l10n.status, l10n.archived);
      add(l10n.animalPdfArchiveReason, archiveReason);
      if (readDate(animal['archivedAt']) case final date?) {
        add(l10n.archiveDateLowercase, formatDate(date));
      }
      add(l10n.archiveNote, animal['archiveNotes']);
    }

    List<AnimalProfilePdfEntry> events(
      List<Map<String, dynamic>> source,
      String dateKey, {
      String? valueKey,
    }) => [
      for (final item in source)
        if (readDate(item[dateKey]) case final date?)
          AnimalProfilePdfEntry(
            formatDate(date, time: true),
            value: valueKey == null || item[valueKey] is! num
                ? null
                : l10n.weightMeasurement(numberFormat.format(item[valueKey])),
            notes: item['notes'] as String?,
          ),
    ];

    final commonName = animal['commonName']?.toString().trim() ?? '';
    final latinName = animal['latinName']?.toString().trim() ?? '';
    return AnimalProfilePdfData(
      name: commonName.isNotEmpty ? commonName : latinName,
      fields: fields,
      labelFields: labelFields,
      primaryPicture: primaryPicture,
      galleryPictures: galleryPictures,
      feedingTitle: l10n.feedingHistory,
      sheddingTitle: l10n.sheddingHistory,
      weightTitle: l10n.weightHistory,
      galleryTitle: l10n.pictureGallery,
      feedings: events(feedings, 'fedAt'),
      shedding: events(shedding, 'shedAt'),
      weights: events(weights, 'measuredAt', valueKey: 'weightGrams'),
    );
  }
}
