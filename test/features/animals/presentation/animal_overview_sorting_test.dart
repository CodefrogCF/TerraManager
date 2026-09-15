import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/animal_category.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/features/animals/presentation/animal_overview_sorting.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';

void main() {
  test(
    'Animal sort criteria keep documented defaults and toggle direction',
    () {
      const defaults = {
        AnimalSortCriterion.created: AnimalSortOrder.createdOldestFirst,
        AnimalSortCriterion.displayName: AnimalSortOrder.displayNameAscending,
        AnimalSortCriterion.age: AnimalSortOrder.ageOldestFirst,
        AnimalSortCriterion.latestFeeding:
            AnimalSortOrder.latestFeedingNewestFirst,
        AnimalSortCriterion.category: AnimalSortOrder.categoryAscending,
      };

      for (final entry in defaults.entries) {
        expect(entry.key.defaultOrder, entry.value);
        expect(entry.value.reversed.reversed, entry.value);
        expect(entry.value.criterion, entry.key);
      }
    },
  );

  Animal animal({
    required int id,
    required String commonName,
    required String latinName,
    required DateTime createdAt,
    DateTime? birthDate,
    AnimalCategory category = AnimalCategory.other,
    AnimalSubcategory? subcategory,
  }) {
    return Animal(
      id: id,
      boxId: 1,
      status: AnimalStatus.active,
      commonName: commonName,
      latinName: latinName,
      category: category,
      subcategory: subcategory,
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

  test('sorts displayed Animal names naturally in both directions', () {
    final animals = [
      animal(
        id: 10,
        commonName: 'Animal 10',
        latinName: 'Species 10',
        createdAt: firstCreated,
      ),
      animal(
        id: 2,
        commonName: 'animal 2',
        latinName: 'Species 2',
        createdAt: secondCreated,
      ),
      animal(
        id: 1,
        commonName: 'Animal 1',
        latinName: 'Species 1',
        createdAt: thirdCreated,
      ),
    ];

    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.displayNameAscending,
        nameOrder: AnimalNameOrder.commonNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [1, 2, 10],
    );
    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.displayNameDescending,
        nameOrder: AnimalNameOrder.commonNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [10, 2, 1],
    );
  });

  test('uses secondary names naturally and ids as a stable fallback', () {
    final animals = [
      animal(
        id: 3,
        commonName: 'Snake',
        latinName: 'Species 10',
        createdAt: firstCreated,
      ),
      animal(
        id: 2,
        commonName: 'Snake',
        latinName: 'Species 2',
        createdAt: secondCreated,
      ),
      animal(
        id: 4,
        commonName: 'Snake',
        latinName: 'Species 2',
        createdAt: thirdCreated,
      ),
    ];

    expect(
      sortAnimalsForOverview(
        animals,
        sortOrder: AnimalSortOrder.displayNameAscending,
        nameOrder: AnimalNameOrder.commonNameFirst,
        latestFeedingTimes: const {},
      ).map((animal) => animal.id),
      [2, 4, 3],
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

  test('groups every category from the taxonomy in canonical order', () {
    final animals = [
      animal(
        id: 1,
        commonName: 'Fallback',
        latinName: 'Other species',
        category: AnimalCategory.other,
        createdAt: firstCreated,
      ),
      animal(
        id: 2,
        commonName: 'Tarantula',
        latinName: 'Arachnid species',
        category: AnimalCategory.arachnid,
        subcategory: AnimalSubcategory.tarantula,
        createdAt: secondCreated,
      ),
      animal(
        id: 3,
        commonName: 'Snake',
        latinName: 'Reptile species',
        category: AnimalCategory.reptile,
        subcategory: AnimalSubcategory.snake,
        createdAt: thirdCreated,
      ),
      animal(
        id: 4,
        commonName: 'Invertebrate',
        latinName: 'Unknown species',
        category: AnimalCategory.otherInvertebrate,
        createdAt: thirdCreated,
      ),
    ];

    List<AnimalCategory> categories(AnimalSortOrder order) =>
        groupAnimalsForCategoryOverview(
          animals,
          sortOrder: order,
          nameOrder: AnimalNameOrder.commonNameFirst,
          subcategoryLabel: (value) => value.name,
        ).map((group) => group.category).toList();

    expect(categories(AnimalSortOrder.categoryAscending), [
      AnimalCategory.reptile,
      AnimalCategory.arachnid,
      AnimalCategory.otherInvertebrate,
      AnimalCategory.other,
    ]);
    expect(categories(AnimalSortOrder.categoryDescending), [
      AnimalCategory.other,
      AnimalCategory.otherInvertebrate,
      AnimalCategory.arachnid,
      AnimalCategory.reptile,
    ]);
  });

  test(
    'keeps subcategories stable and sorts names naturally inside groups',
    () {
      final animals = [
        animal(
          id: 1,
          commonName: 'Animal 10',
          latinName: 'Species 10',
          category: AnimalCategory.arachnid,
          subcategory: AnimalSubcategory.otherSpider,
          createdAt: firstCreated,
        ),
        animal(
          id: 2,
          commonName: 'Animal 2',
          latinName: 'Species 2',
          category: AnimalCategory.arachnid,
          subcategory: AnimalSubcategory.otherSpider,
          createdAt: secondCreated,
        ),
        animal(
          id: 3,
          commonName: 'Tarantula',
          latinName: 'Species T',
          category: AnimalCategory.arachnid,
          subcategory: AnimalSubcategory.tarantula,
          createdAt: thirdCreated,
        ),
        animal(
          id: 4,
          commonName: 'Other',
          latinName: 'Species O',
          category: AnimalCategory.arachnid,
          subcategory: AnimalSubcategory.other,
          createdAt: thirdCreated,
        ),
        animal(
          id: 5,
          commonName: 'Unspecified',
          latinName: 'Species U',
          category: AnimalCategory.arachnid,
          createdAt: thirdCreated,
        ),
      ];
      String label(AnimalSubcategory value) => switch (value) {
        AnimalSubcategory.otherSpider => 'A other spider',
        AnimalSubcategory.tarantula => 'B tarantula',
        _ => value.name,
      };

      final ascending = groupAnimalsForCategoryOverview(
        animals,
        sortOrder: AnimalSortOrder.categoryAscending,
        nameOrder: AnimalNameOrder.commonNameFirst,
        subcategoryLabel: label,
      ).single;
      final descending = groupAnimalsForCategoryOverview(
        animals,
        sortOrder: AnimalSortOrder.categoryDescending,
        nameOrder: AnimalNameOrder.commonNameFirst,
        subcategoryLabel: label,
      ).single;

      expect(ascending.subgroups.map((group) => group.subcategory), [
        AnimalSubcategory.otherSpider,
        AnimalSubcategory.tarantula,
        AnimalSubcategory.other,
        null,
      ]);
      expect(descending.subgroups.map((group) => group.subcategory), [
        AnimalSubcategory.otherSpider,
        AnimalSubcategory.tarantula,
        AnimalSubcategory.other,
        null,
      ]);
      expect(ascending.subgroups.first.animals.map((animal) => animal.id), [
        2,
        1,
      ]);
    },
  );

  test('omits unnecessary subcategory headings', () {
    final group = groupAnimalsForCategoryOverview(
      [
        animal(
          id: 1,
          commonName: 'Gecko',
          latinName: 'Species one',
          category: AnimalCategory.reptile,
          createdAt: firstCreated,
        ),
      ],
      sortOrder: AnimalSortOrder.categoryAscending,
      nameOrder: AnimalNameOrder.commonNameFirst,
      subcategoryLabel: (value) => value.name,
    ).single;

    expect(group.subgroups, hasLength(1));
    expect(group.subgroups.single.showHeading, isFalse);
    expect(group.subgroups.single.subcategory, isNull);
  });
}
