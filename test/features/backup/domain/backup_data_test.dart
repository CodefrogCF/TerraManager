import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/backup/domain/backup_data.dart';

void main() {
  test('backup domain data survives json round trip', () {
    final original = BackupData(
      boxes: [
        BackupBox(
          id: 1,
          qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 2),
        ),
      ],
      animals: [
        BackupAnimal(
          id: 10,
          boxId: 1,
          status: 'active',
          commonName: 'Test Snake',
          latinName: 'Pantherophis guttatus',
          sex: 'female',
          birthDate: DateTime(2024, 1, 1),
          birthDateAccuracy: 'yearKnown',
          tempMin: 24,
          tempMax: 28,
          humidityMin: 40,
          humidityMax: 60,
          pictureMediaPath: 'media/animals/10.jpg',
          notes: 'Test animal',
          archiveReason: null,
          archivedAt: null,
          archiveNotes: null,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 2),
        ),
      ],
      feedingEvents: [
        BackupFeedingEvent(
          id: 100,
          animalId: 10,
          fedAt: DateTime(2026, 8, 20, 18, 30),
          notes: 'Mouse',
        ),
      ],
    );

    final restored = BackupData.fromJson(original.toJson());

    expect(restored.boxes.length, 1);

    expect(restored.animals.length, 1);

    expect(restored.feedingEvents.length, 1);

    expect(restored.boxes.single.id, 1);

    expect(restored.animals.single.boxId, 1);

    expect(restored.animals.single.pictureMediaPath, 'media/animals/10.jpg');

    expect(restored.feedingEvents.single.animalId, 10);

    expect(restored.animals.single.sex, 'female');

    expect(restored.animals.single.birthDateAccuracy, 'yearKnown');

    expect(restored.feedingEvents.single.notes, 'Mouse');
  });

  test('archived animal can exist without box assignment', () {
    final original = BackupAnimal(
      id: 11,
      boxId: null,
      status: 'archived',
      commonName: 'Archived Snake',
      latinName: 'Pantherophis guttatus',
      sex: null,
      birthDate: null,
      birthDateAccuracy: null,
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
      pictureMediaPath: null,
      notes: null,
      archiveReason: 'rehomed',
      archivedAt: DateTime(2026, 9, 1),
      archiveNotes: 'Moved to another keeper',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

    final restored = BackupAnimal.fromJson(original.toJson());

    expect(restored.status, 'archived');

    expect(restored.boxId, isNull);

    expect(restored.archiveReason, 'rehomed');

    expect(restored.archivedAt, DateTime(2026, 9, 1));
  });
}
