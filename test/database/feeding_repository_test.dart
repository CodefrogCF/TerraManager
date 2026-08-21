import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';

void main() {
  late AppDatabase database;
  late FeedingRepository repository;

  setUp(() {
    database = AppDatabase.test(
      NativeDatabase.memory(),
    );

    repository = FeedingRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('can add a feeding', () async {
    final boxId = await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    final animalId = await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: boxId,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            tempMin: 24.0,
            tempMax: 28.0,
            humidityMin: 40.0,
            humidityMax: 60.0,
          ),
        );

    final fedAt = DateTime(2026, 8, 21, 12, 30);

    final feedingId = await repository.addFeeding(
      animalId,
      fedAt,
    );

    final feeding = await (
      database.select(database.feedingEvents)
        ..where((event) => event.id.equals(feedingId))
    ).getSingle();

    expect(feeding.animalId, animalId);
    expect(feeding.fedAt, fedAt);
    expect(feeding.notes, isNull);
  });
}