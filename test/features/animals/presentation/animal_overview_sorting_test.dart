import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/features/animals/presentation/animal_overview_sorting.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';

void main() {
  Animal animal({
    required int id,
    required String commonName,
    required String latinName,
    required DateTime createdAt,
    DateTime? birthDate,
  }) {
    return Animal(
      id: id,
      boxId: 1,
      status: AnimalStatus.active,
      commonName: commonName,
      latinName: latinName,
      birthDate: birthDate,
      tempMin: 20,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 70,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  final firstCreated = DateTime(2026, 9, 1);
  final secondCreated = DateTime(2026, 9, 2);
  final thirdCreated = DateTime(2026, 9, 3);

  test('sorts Animals by creation time without changing the source list', () {
    final animals = [
      animal(
        id: 1,
        commonName: 'One',
        latinName: 'Species one',
        createdAt: secondCreated,
      ),
      animal(
        id: 2,
        commonName: 'Two',
        latinName: 'Species two',
        createdAt: thirdCreated,
      ),
      animal(
        id: 3,
        commonName: 'Three',
        latinName: 'Species three',
        createdAt: firstCreated,
      ),
    ];

    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.createdOldestFirst,
        nameOrder: AnimalNameOrder.commonNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [3, 1, 2],
    );
    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.createdNewestFirst,
        nameOrder: AnimalNameOrder.commonNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [2, 1, 3],
    );
    expect(animals.map((animal) => animal.id), [1, 2, 3]);
  });

  test('sorts by the currently displayed primary Animal name', () {
    final animals = [
      animal(
        id: 1,
        commonName: 'Zebra',
        latinName: 'Alpha species',
        createdAt: firstCreated,
      ),
      animal(
        id: 2,
        commonName: 'ant',
        latinName: 'Zeta species',
        createdAt: secondCreated,
      ),
    ];

    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.displayNameAscending,
        nameOrder: AnimalNameOrder.commonNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [2, 1],
    );
    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.displayNameAscending,
        nameOrder: AnimalNameOrder.latinNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [1, 2],
    );
    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.displayNameDescending,
        nameOrder: AnimalNameOrder.commonNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [1, 2],
    );
  });

  test('places missing birth dates after known ages in both directions', () {
    final animals = [
      animal(
        id: 1,
        commonName: 'Older',
        latinName: 'Species older',
        birthDate: DateTime(2020),
        createdAt: firstCreated,
      ),
      animal(
        id: 2,
        commonName: 'Unknown',
        latinName: 'Species unknown',
        createdAt: secondCreated,
      ),
      animal(
        id: 3,
        commonName: 'Younger',
        latinName: 'Species younger',
        birthDate: DateTime(2024),
        createdAt: thirdCreated,
      ),
    ];

    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.ageOldestFirst,
        nameOrder: AnimalNameOrder.commonNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [1, 3, 2],
    );
    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.ageYoungestFirst,
        nameOrder: AnimalNameOrder.commonNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [3, 1, 2],
    );
  });

  test(
    'sorts latest feedings and treats never-fed Animals deterministically',
    () {
      final animals = [
        animal(
          id: 1,
          commonName: 'Recent',
          latinName: 'Species recent',
          createdAt: firstCreated,
        ),
        animal(
          id: 2,
          commonName: 'Old',
          latinName: 'Species old',
          createdAt: secondCreated,
        ),
        animal(
          id: 3,
          commonName: 'Never',
          latinName: 'Species never',
          createdAt: thirdCreated,
        ),
      ];
      final latestFeedingTimes = {
        1: DateTime(2026, 9, 8),
        2: DateTime(2026, 9, 2),
      };

      expect(
        sortAnimalsForOverview(
          animals,
          sortOrder: AnimalSortOrder.latestFeedingNewestFirst,
          nameOrder: AnimalNameOrder.commonNameFirst,
          latestFeedingTimes: latestFeedingTimes,
        ).map((animal) => animal.id),
        [1, 2, 3],
      );
      expect(
        sortAnimalsForOverview(
          animals,
          sortOrder: AnimalSortOrder.latestFeedingOldestFirst,
          nameOrder: AnimalNameOrder.commonNameFirst,
          latestFeedingTimes: latestFeedingTimes,
        ).map((animal) => animal.id),
        [3, 2, 1],
      );
    },
  );
}
