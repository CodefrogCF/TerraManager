import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/animal_weight_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/core/database/repositories/shedding_repository.dart';
import 'package:terramanager/features/animals/application/local_animal_profile_pdf_loader.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  test('Standalone loads the selected Animal and excludes the primary from gallery append', () async {
    final database = AppDatabase.test(NativeDatabase.memory());
    addTearDown(database.close);
    final boxId = await database
        .into(database.boxes)
        .insert(BoxesCompanion.insert(qrId: 'animal-pdf-test-box'));
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Frida',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      originHabitat: 'Forest',
    );
    final pictures = PictureGalleryRepository(database);
    await pictures.addAnimalPicture(
      animalId: animalId,
      fileName: 'primary.png',
      mimeType: 'image/png',
      data: Uint8List.fromList([1]),
    );
    await pictures.addAnimalPicture(
      animalId: animalId,
      fileName: 'other.png',
      mimeType: 'image/png',
      data: Uint8List.fromList([2]),
      makePrimary: false,
    );
    await FeedingRepository(database)
        .addFeeding(animalId, DateTime(2026, 10, 1, 19), notes: 'Mouse');
    await SheddingRepository(
      database,
    ).add(animalId: animalId, shedAt: DateTime(2026, 9, 1), notes: 'Complete');
    await AnimalWeightRepository(database).add(
      animalId: animalId,
      weightGrams: 123,
      measuredAt: DateTime(2026, 9, 2),
    );

    final loader = LocalAnimalProfilePdfLoader(database);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final basic = await loader.load(animalId, l10n, includeGallery: false);
    expect(basic.name, 'Frida');
    expect(basic.primaryPicture, [1]);
    expect(basic.galleryPictures, isEmpty);
    expect(basic.feedings.single.notes, 'Mouse');
    expect(basic.shedding.single.notes, 'Complete');
    expect(basic.weights.single.value, '123 g');
    expect(basic.fields.map((field) => field.value), contains('Forest'));

    final complete = await loader.load(animalId, l10n, includeGallery: true);
    expect(complete.galleryPictures.single, [2]);
  });
}
