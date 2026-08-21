import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/sex.dart';

void main() {

  late AppDatabase database;

setUp(() {
  database = AppDatabase.test(
    NativeDatabase.memory(),
  );
});

  tearDown(() async {
    await database.close();
  });

  test('can create a box and assign an animal to it', () async {
    // Arrange
    const qrId = 'TM:BOX:test-box-001';

    // Act: create box
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: qrId,
          ),
        );

    // Act: create animal
    final animalId = await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: 'Test Animal',
            latinName: 'Testus animalis',
            sex: const Value(Sex.male),
            birthDate: Value(DateTime(2021, 3, 15)),
            birthDateAccuracy: const Value(
              BirthDateAccuracy.exact,
            ),
            tempMin: 22.0,
            tempMax: 28.0,
            humidityMin: 60.0,
            humidityMax: 75.0,
          ),
        );

    // Act: create feeding event
    final feedingEventId =
    await database.into(database.feedingEvents).insert(
          FeedingEventsCompanion.insert(
            animalId: animalId,
            fedAt: DateTime(2026, 8, 20, 7, 30),
            notes: const Value('Frostfutter'),
          ),
        );

    expect(feedingEventId, greaterThan(0));

    // Assert
    expect(boxId, greaterThan(0));
    expect(animalId, greaterThan(0));

    final animal = await (database.select(database.animals)
          ..where((animal) => animal.id.equals(animalId)))
        .getSingle();

    expect(animal.boxId, boxId);
    expect(animal.commonName, 'Test Animal');
    expect(animal.sex, Sex.male);
    expect(animal.birthDateAccuracy, BirthDateAccuracy.exact);
    expect(animal.tempMin, 22.0);
    expect(animal.tempMax, 28.0);
    expect(animal.humidityMin, 60.0);
    expect(animal.humidityMax, 75.0);

    final feedingEvent =
    await (database.select(database.feedingEvents)
          ..where((event) => event.id.equals(feedingEventId)))
        .getSingle();

    expect(feedingEvent.animalId, animalId);
    expect(
      feedingEvent.fedAt,
      DateTime(2026, 8, 20, 7, 30),
    );
    expect(feedingEvent.notes, 'Frostfutter');

    await database.into(database.feedingEvents).insert(
      FeedingEventsCompanion.insert(
        animalId: animalId,
        fedAt: DateTime(2026, 8, 13, 7, 30),
      ),
    );

    final latestFeeding = await (database.select(database.feedingEvents)
          ..where((event) => event.animalId.equals(animalId))
          ..orderBy([
            (event) => OrderingTerm(
                  expression: event.fedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingle();

    expect(
      latestFeeding.fedAt,
      DateTime(2026, 8, 20, 7, 30),
    );

  });
}