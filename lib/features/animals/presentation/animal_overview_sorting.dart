import '../../../core/database/app_database.dart';
import '../../../core/database/enums/animal_category.dart';
import '../../../core/sorting/natural_string_comparator.dart';
import '../../settings/animal_name_order.dart';
import '../../settings/animal_sort_order.dart';
import 'animal_display_names.dart';

List<Animal> sortAnimalsForOverview(
  Iterable<Animal> animals, {
  required AnimalSortOrder sortOrder,
  required AnimalNameOrder nameOrder,
  required Map<int, DateTime> latestFeedingTimes,
}) {
  final sortedAnimals = animals.toList();

  sortedAnimals.sort((first, second) {
    return switch (sortOrder) {
      AnimalSortOrder.createdOldestFirst => _compareDates(
        first.createdAt,
        second.createdAt,
        first.id,
        second.id,
        descending: false,
      ),
      AnimalSortOrder.createdNewestFirst => _compareDates(
        first.createdAt,
        second.createdAt,
        first.id,
        second.id,
        descending: true,
      ),
      AnimalSortOrder.displayNameAscending => _compareDisplayNames(
        first,
        second,
        nameOrder,
        descending: false,
      ),
      AnimalSortOrder.displayNameDescending => _compareDisplayNames(
        first,
        second,
        nameOrder,
        descending: true,
      ),
      AnimalSortOrder.ageOldestFirst => _compareNullableDates(
        first.birthDate,
        second.birthDate,
        first.id,
        second.id,
        descending: false,
        missingFirst: false,
      ),
      AnimalSortOrder.ageYoungestFirst => _compareNullableDates(
        first.birthDate,
        second.birthDate,
        first.id,
        second.id,
        descending: true,
        missingFirst: false,
      ),
      AnimalSortOrder.latestFeedingNewestFirst => _compareNullableDates(
        latestFeedingTimes[first.id],
        latestFeedingTimes[second.id],
        first.id,
        second.id,
        descending: true,
        missingFirst: false,
      ),
      AnimalSortOrder.latestFeedingOldestFirst => _compareNullableDates(
        latestFeedingTimes[first.id],
        latestFeedingTimes[second.id],
        first.id,
        second.id,
        descending: false,
        missingFirst: true,
      ),
      AnimalSortOrder.categoryAscending => _compareDisplayNames(
        first,
        second,
        nameOrder,
        descending: false,
      ),
      AnimalSortOrder.categoryDescending => _compareDisplayNames(
        first,
        second,
        nameOrder,
        descending: true,
      ),
    };
  });

  return sortedAnimals;
}

class AnimalCategoryOverviewGroup {
  final AnimalCategory category;
  final List<AnimalSubcategoryOverviewGroup> subgroups;

  const AnimalCategoryOverviewGroup({
    required this.category,
    required this.subgroups,
  });

  Iterable<Animal> get animals =>
      subgroups.expand((subgroup) => subgroup.animals);
}

class AnimalSubcategoryOverviewGroup {
  final AnimalSubcategory? subcategory;
  final bool showHeading;
  final List<Animal> animals;

  const AnimalSubcategoryOverviewGroup({
    required this.subcategory,
    required this.showHeading,
    required this.animals,
  });
}

List<AnimalCategoryOverviewGroup> groupAnimalsForCategoryOverview(
  Iterable<Animal> animals, {
  required AnimalSortOrder sortOrder,
  required AnimalNameOrder nameOrder,
  required Map<int, DateTime> latestFeedingTimes,
  required String Function(AnimalSubcategory subcategory) subcategoryLabel,
}) {
  final animalsByCategory = <AnimalCategory, List<Animal>>{};
  for (final animal in animals) {
    animalsByCategory.putIfAbsent(animal.category, () => []).add(animal);
  }

  final categories = AnimalCategory.values
      .where(animalsByCategory.containsKey)
      .toList(growable: false);
  return categories
      .map((category) {
        final categoryAnimals = animalsByCategory[category]!;
        final hasSpecifiedSubcategory = categoryAnimals.any(
          (animal) => animal.subcategory != null,
        );

        if (!hasSpecifiedSubcategory) {
          final sorted = sortAnimalsForOverview(
            categoryAnimals,
            sortOrder: sortOrder,
            nameOrder: nameOrder,
            latestFeedingTimes: latestFeedingTimes,
          );
          return AnimalCategoryOverviewGroup(
            category: category,
            subgroups: [
              AnimalSubcategoryOverviewGroup(
                subcategory: null,
                showHeading: false,
                animals: sorted,
              ),
            ],
          );
        }

        final animalsBySubcategory = <AnimalSubcategory?, List<Animal>>{};
        for (final animal in categoryAnimals) {
          animalsBySubcategory
              .putIfAbsent(animal.subcategory, () => [])
              .add(animal);
        }

        final namedSubcategories =
            animalsBySubcategory.keys
                .whereType<AnimalSubcategory>()
                .where((subcategory) => subcategory != AnimalSubcategory.other)
                .toList()
              ..sort(
                (first, second) => compareNaturalStrings(
                  subcategoryLabel(first),
                  subcategoryLabel(second),
                ),
              );
        final orderedSubcategories = <AnimalSubcategory?>[
          ...namedSubcategories,
          if (animalsBySubcategory.containsKey(AnimalSubcategory.other))
            AnimalSubcategory.other,
          if (animalsBySubcategory.containsKey(null)) null,
        ];

        return AnimalCategoryOverviewGroup(
          category: category,
          subgroups: orderedSubcategories
              .map((subcategory) {
                final sorted = sortAnimalsForOverview(
                  animalsBySubcategory[subcategory]!,
                  sortOrder: sortOrder,
                  nameOrder: nameOrder,
                  latestFeedingTimes: latestFeedingTimes,
                );
                return AnimalSubcategoryOverviewGroup(
                  subcategory: subcategory,
                  showHeading: true,
                  animals: sorted,
                );
              })
              .toList(growable: false),
        );
      })
      .toList(growable: false);
}

int _compareDisplayNames(
  Animal first,
  Animal second,
  AnimalNameOrder nameOrder, {
  required bool descending,
}) {
  final firstNames = AnimalDisplayNames.fromOrder(
    commonName: first.commonName,
    latinName: first.latinName,
    order: nameOrder,
  );
  final secondNames = AnimalDisplayNames.fromOrder(
    commonName: second.commonName,
    latinName: second.latinName,
    order: nameOrder,
  );
  final primaryComparison = _compareText(
    firstNames.primary,
    secondNames.primary,
    descending: descending,
  );

  if (primaryComparison != 0) {
    return primaryComparison;
  }

  final secondaryComparison = _compareText(
    firstNames.secondary,
    secondNames.secondary,
    descending: descending,
  );

  if (secondaryComparison != 0) {
    return secondaryComparison;
  }

  return first.id.compareTo(second.id);
}

int _compareText(String first, String second, {required bool descending}) {
  return descending
      ? compareNaturalStrings(second, first)
      : compareNaturalStrings(first, second);
}

int _compareNullableDates(
  DateTime? first,
  DateTime? second,
  int firstId,
  int secondId, {
  required bool descending,
  required bool missingFirst,
}) {
  if (first == null || second == null) {
    if (first == null && second == null) {
      return firstId.compareTo(secondId);
    }

    if (first == null) {
      return missingFirst ? -1 : 1;
    }

    return missingFirst ? 1 : -1;
  }

  return _compareDates(
    first,
    second,
    firstId,
    secondId,
    descending: descending,
  );
}

int _compareDates(
  DateTime first,
  DateTime second,
  int firstId,
  int secondId, {
  required bool descending,
}) {
  final comparison = descending
      ? second.compareTo(first)
      : first.compareTo(second);

  if (comparison != 0) {
    return comparison;
  }

  return descending ? secondId.compareTo(firstId) : firstId.compareTo(secondId);
}
