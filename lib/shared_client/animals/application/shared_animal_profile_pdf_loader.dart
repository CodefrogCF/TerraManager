import 'dart:typed_data';

import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/animal_category.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/features/animals/application/animal_profile_pdf_content.dart';
import 'package:terramanager/features/animals/application/animal_profile_pdf_export_service.dart';
import 'package:terramanager/l10n/app_localizations_labels.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';

class SharedAnimalProfilePdfLoader {
  const SharedAnimalProfilePdfLoader(this.api);

  final SharedApiClient api;

  Future<AnimalProfilePdfData> load(
    int animalId,
    AppLocalizations l10n,
    List<Map<String, dynamic>> boxes, {
    required bool includeGallery,
  }) async {
    final animalFuture = api.animal(animalId);
    final feedingFuture = api.feedings(animalId);
    final sheddingFuture = api.shedding(animalId);
    final weightFuture = api.weights(animalId);
    final picturesFuture = api.pictures('animals', animalId);
    final animal = await animalFuture;
    final feedings = await feedingFuture;
    final shedding = await sheddingFuture;
    final weights = await weightFuture;
    final pictures = await picturesFuture;

    final primaryId =
        animal['pictureMediaId'] as int? ??
        pictures
                .where((picture) => picture['isPrimary'] == true)
                .firstOrNull?['mediaId']
            as int? ??
        pictures.firstOrNull?['mediaId'] as int?;
    final primary = primaryId == null ? null : await api.mediaBytes(primaryId);
    final gallery = <Uint8List>[];
    if (includeGallery) {
      final chronologicalPictures = [...pictures]
        ..sort((a, b) {
          final first = DateTime.tryParse(a['capturedAt']?.toString() ?? '');
          final second = DateTime.tryParse(b['capturedAt']?.toString() ?? '');
          final capturedAt = first == null
              ? (second == null ? 0 : -1)
              : second == null
              ? 1
              : first.compareTo(second);
          if (capturedAt != 0) return capturedAt;
          final order = ((a['sortOrder'] as int?) ?? 0).compareTo(
            (b['sortOrder'] as int?) ?? 0,
          );
          return order != 0
              ? order
              : ((a['associationId'] ?? a['mediaId']) as int).compareTo(
                  (b['associationId'] ?? b['mediaId']) as int,
                );
        });
      // Legacy primary pictures may not have a gallery capture date.
      if (primary != null &&
          !pictures.any((picture) => picture['mediaId'] == primaryId)) {
        gallery.add(primary);
      }
      for (final picture in chronologicalPictures) {
        final mediaId = picture['mediaId'] as int;
        gallery.add(
          mediaId == primaryId && primary != null
              ? primary
              : await api.mediaBytes(mediaId),
        );
      }
    }
    final box = boxes
        .where((entry) => entry['id'] == animal['boxId'])
        .firstOrNull;
    final category = AnimalCategory.values
        .where((value) => value.name == animal['category'])
        .firstOrNull;
    final subcategory = AnimalSubcategory.values
        .where((value) => value.name == animal['subcategory'])
        .firstOrNull;
    final sex = Sex.values
        .where((value) => value.name == animal['sex'])
        .firstOrNull;
    final accuracy = BirthDateAccuracy.values
        .where((value) => value.name == animal['birthDateAccuracy'])
        .firstOrNull;
    final archiveReason = AnimalArchiveReason.values
        .where((value) => value.name == animal['archiveReason'])
        .firstOrNull;

    return AnimalProfilePdfContent.build(
      l10n: l10n,
      animal: animal,
      category: category == null
          ? (animal['category']?.toString() ?? '')
          : l10n.animalCategoryLabel(category),
      subcategory: subcategory == null
          ? animal['subcategory']?.toString()
          : l10n.animalSubcategoryLabel(subcategory),
      sex: sex == null || sex == Sex.unknown ? null : l10n.animalSexLabel(sex),
      birthAccuracy: accuracy == null
          ? null
          : l10n.birthAccuracyLabel(accuracy),
      archiveReason: archiveReason == null
          ? null
          : l10n.animalArchiveReasonLabel(archiveReason),
      box: box == null
          ? animal['boxId'] is int
                ? l10n.boxLabel(animal['boxId'] as int)
                : null
          : boxLabel(box),
      primaryPicture: primary,
      galleryPictures: gallery,
      feedings: feedings,
      shedding: shedding,
      weights: weights,
    );
  }
}
