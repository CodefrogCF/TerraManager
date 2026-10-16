import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums/sex.dart';
import '../../../core/database/repositories/animal_repository.dart';
import '../../../core/database/repositories/animal_weight_repository.dart';
import '../../../core/database/repositories/box_repository.dart';
import '../../../core/database/repositories/feeding_repository.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/database/repositories/picture_gallery_repository.dart';
import '../../../core/database/repositories/shedding_repository.dart';
import '../../../l10n/app_localizations_labels.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../boxes/presentation/box_selection_label.dart';
import 'animal_profile_pdf_content.dart';
import 'animal_profile_pdf_export_service.dart';

class LocalAnimalProfilePdfLoader {
  const LocalAnimalProfilePdfLoader(this.database);

  final AppDatabase database;

  Future<AnimalProfilePdfData> load(
    int animalId,
    AppLocalizations l10n, {
    required bool includeGallery,
  }) async {
    final animal = await AnimalRepository(database).getAnimalById(animalId);
    if (animal == null) throw StateError('Animal $animalId no longer exists');
    final box = animal.boxId == null
        ? null
        : await BoxRepository(database).getBoxById(animal.boxId!);
    final gallery = await PictureGalleryRepository(database)
        .getAnimalPictures(animalId);
    final primaryId =
        animal.pictureMediaId ??
        gallery.where((entry) => entry.isPrimary).firstOrNull?.media.id ??
        gallery.firstOrNull?.media.id;
    Uint8List? primary = gallery
        .where((entry) => entry.media.id == primaryId)
        .firstOrNull
        ?.media
        .data;
    if (primary == null && primaryId != null) {
      primary = (await MediaRepository(database).getMediaById(primaryId))?.data;
    }
    if (primary == null && animal.picturePath?.trim().isNotEmpty == true) {
      try {
        primary = await XFile(animal.picturePath!).readAsBytes();
      } catch (_) {
        // A missing legacy picture does not prevent a text-only export.
      }
    }
    final feedings = await FeedingRepository(database)
        .getFeedingsForAnimal(animalId);
    final shedding = await SheddingRepository(database).getHistory(animalId);
    final weights = await AnimalWeightRepository(database).getHistory(animalId);

    return AnimalProfilePdfContent.build(
      l10n: l10n,
      animal: {
        'commonName': animal.commonName,
        'latinName': animal.latinName,
        'birthDate': animal.birthDate,
        'tempMin': animal.tempMin,
        'tempMax': animal.tempMax,
        'nighttimeTemperature': animal.nighttimeTemperature,
        'nighttimeTemperatureMin': animal.nighttimeTemperatureMin,
        'nighttimeTemperatureMax': animal.nighttimeTemperatureMax,
        'humidityMin': animal.humidityMin,
        'humidityMax': animal.humidityMax,
        'originHabitat': animal.originHabitat,
        'restOrDormancyPeriods': animal.restOrDormancyPeriods,
        'temperatureZones': animal.temperatureZones,
        'notes': animal.notes,
        'weight': animal.weight,
        'sheddingNotes': animal.sheddingNotes,
        'status': animal.status.name,
        'archivedAt': animal.archivedAt,
        'archiveNotes': animal.archiveNotes,
      },
      category: l10n.animalCategoryLabel(animal.category),
      subcategory: animal.subcategory == null
          ? null
          : l10n.animalSubcategoryLabel(animal.subcategory!),
      sex: animal.sex == null || animal.sex == Sex.unknown
          ? null
          : l10n.animalSexLabel(animal.sex!),
      birthAccuracy: animal.birthDateAccuracy == null
          ? null
          : l10n.birthAccuracyLabel(animal.birthDateAccuracy!),
      archiveReason: animal.archiveReason == null
          ? null
          : l10n.animalArchiveReasonLabel(animal.archiveReason!),
      box: animal.boxId == null
          ? null
          : box == null
          ? l10n.boxLabel(animal.boxId!)
          : boxSelectionLabel(l10n, box),
      primaryPicture: primary,
      galleryPictures: includeGallery
          ? [
              for (final entry in gallery)
                if (entry.media.id != primaryId) entry.media.data,
            ]
          : const [],
      feedings: [
        for (final event in feedings)
          {'fedAt': event.fedAt, 'notes': event.notes},
      ],
      shedding: [
        for (final event in shedding)
          {'shedAt': event.shedAt, 'notes': event.notes},
      ],
      weights: [
        for (final entry in weights)
          {'measuredAt': entry.measuredAt, 'weightGrams': entry.weightGrams},
      ],
    );
  }
}
