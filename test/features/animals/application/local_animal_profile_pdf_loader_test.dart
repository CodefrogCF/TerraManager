import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
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
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';
import 'package:terramanager/features/feedings/domain/feeding_field_values.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  test(
    'Standalone loads saved Feeding fields with their original labels',
    () async {
      final database = AppDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);
      final boxId = await database
          .into(database.boxes)
          .insert(BoxesCompanion.insert(qrId: 'feeding-fields-pdf-box'));
      final animalId = await AnimalRepository(database).createAnimal(
        boxId: boxId,
        commonName: 'Frida',
        latinName: 'Species',
        tempMin: 24,
        tempMax: 28,
        humidityMin: 40,
        humidityMax: 60,
      );
      await database
          .into(database.feedingEvents)
          .insert(
            FeedingEventsCompanion.insert(
              animalId: animalId,
              fedAt: DateTime(2026, 10, 2, 19),
              customFieldsJson: Value(
                encodeFeedingFieldValues(const [
                  FeedingFieldValue(
                    CustomFieldTemplate(
                      id: '11111111-1111-4111-8111-111111111111',
                      target: CustomFieldTarget.feeding,
                      type: CustomFieldType.integer,
                      label: 'Anzahl',
                    ),
                    4,
                  ),
                  FeedingFieldValue(
                    CustomFieldTemplate(
                      id: '22222222-2222-4222-8222-222222222222',
                      target: CustomFieldTarget.feeding,
                      type: CustomFieldType.choice,
                      label: 'Futterart',
                      options: ['Drosophila'],
                    ),
                    'Drosophila',
                  ),
                ]),
              ),
            ),
          );
      await FeedingRepository(
        database,
      ).addFeeding(animalId, DateTime(2026, 10, 1, 19), notes: 'Ältere Notiz');

      final data = await LocalAnimalProfilePdfLoader(database).load(
        animalId,
        lookupAppLocalizations(const Locale('de')),
        includeGallery: false,
      );
      expect(data.feedings.first.date, '02.10.2026 19:00');
      expect(
        data.feedings.first.fields.map((field) => (field.label, field.value)),
        [('Anzahl', '4'), ('Futterart', 'Drosophila')],
      );
      expect(data.feedings.last.notes, 'Ältere Notiz');
      expect(data.feedings.last.fields, isEmpty);
    },
  );

  test('Standalone includes the primary at its capture date in the complete gallery', () async {
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
      capturedAt: DateTime(2026, 10, 2),
    );
    await pictures.addAnimalPicture(
      animalId: animalId,
      fileName: 'other.png',
      mimeType: 'image/png',
      data: Uint8List.fromList([2]),
      capturedAt: DateTime(2026, 10, 1),
      makePrimary: false,
    );
    await pictures.addAnimalPicture(
      animalId: animalId,
      fileName: 'newer.png',
      mimeType: 'image/png',
      data: Uint8List.fromList([3]),
      capturedAt: DateTime(2026, 10, 3),
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
    expect(complete.galleryPictures.map((bytes) => bytes.single), [2, 1, 3]);
  });
}
