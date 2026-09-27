import 'package:flutter/material.dart';
import 'package:terramanager/core/database/enums/animal_category.dart';
import 'package:terramanager/core/sorting/natural_string_comparator.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/l10n/app_localizations_context.dart';
import 'package:terramanager/l10n/app_localizations_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/record_labels.dart';
import 'package:terramanager/shared_client/shared/presentation/record_sorting.dart';

List<Map<String, dynamic>> sortSharedAnimalsForOverview(
  Iterable<Map<String, dynamic>> animals, {
  required AnimalSortOrder order,
  required AnimalNameOrder nameOrder,
}) {
  final values = animals.toList();
  values.sort((a, b) {
    switch (order.normalized) {
      case AnimalSortOrder.createdOldestFirst:
        return compareSharedDates('createdAt', a, b, descending: false);
      case AnimalSortOrder.createdNewestFirst:
        return compareSharedDates('createdAt', a, b, descending: true);
      case AnimalSortOrder.ageOldestFirst:
        return compareSharedDates('birthDate', a, b, descending: false);
      case AnimalSortOrder.ageYoungestFirst:
        return compareSharedDates('birthDate', a, b, descending: true);
      case AnimalSortOrder.latestFeedingNewestFirst:
        return compareSharedDates('latestFeedingAt', a, b, descending: true);
      case AnimalSortOrder.latestFeedingOldestFirst:
        return compareSharedDates(
          'latestFeedingAt',
          a,
          b,
          descending: false,
          missingFirst: true,
        );
      case AnimalSortOrder.displayNameAscending:
      case AnimalSortOrder.displayNameDescending:
      case AnimalSortOrder.categoryAscending:
      case AnimalSortOrder.categoryDescending:
        final descending = order == AnimalSortOrder.displayNameDescending;
        final result = compareNaturalStrings(
          animalLabel(a, order: nameOrder),
          animalLabel(b, order: nameOrder),
        );
        if (result != 0) return descending ? -result : result;
        final secondaryA = nameOrder == AnimalNameOrder.commonNameFirst
            ? a['latinName'] as String? ?? ''
            : a['commonName'] as String? ?? '';
        final secondaryB = nameOrder == AnimalNameOrder.commonNameFirst
            ? b['latinName'] as String? ?? ''
            : b['commonName'] as String? ?? '';
        final secondary = compareNaturalStrings(secondaryA, secondaryB);
        if (secondary != 0) return descending ? -secondary : secondary;
        return recordId(a).compareTo(recordId(b));
    }
  });
  return values;
}

List<Object> sharedAnimalOverviewRows(
  BuildContext context,
  List<Map<String, dynamic>> sortedAnimals, {
  required bool groupCategories,
}) {
  if (!groupCategories) return List<Object>.of(sortedAnimals);
  final rows = <Object>[];
  for (final category in AnimalCategory.values) {
    final categoryAnimals = sortedAnimals.where((animal) {
      final known = AnimalCategory.values.any(
        (value) => value.name == animal['category'],
      );
      return known
          ? animal['category'] == category.name
          : category == AnimalCategory.other;
    }).toList();
    if (categoryAnimals.isEmpty) continue;
    rows.add(context.l10n.animalCategoryPluralLabel(category));
    final named =
        category.subcategories
            .where((subcategory) => subcategory != AnimalSubcategory.other)
            .where(
              (subcategory) => categoryAnimals.any(
                (animal) => animal['subcategory'] == subcategory.name,
              ),
            )
            .toList()
          ..sort(
            (a, b) => compareNaturalStrings(
              context.l10n.animalSubcategoryPluralLabel(a),
              context.l10n.animalSubcategoryPluralLabel(b),
            ),
          );
    final hasSubcategory = categoryAnimals.any(
      (animal) => category.subcategories.any(
        (subcategory) => subcategory.name == animal['subcategory'],
      ),
    );
    if (!hasSubcategory) {
      rows.addAll(categoryAnimals);
      continue;
    }
    for (final subcategory in [
      ...named,
      if (category.subcategories.contains(AnimalSubcategory.other) &&
          categoryAnimals.any(
            (animal) => animal['subcategory'] == AnimalSubcategory.other.name,
          ))
        AnimalSubcategory.other,
    ]) {
      rows.add(context.l10n.animalSubcategoryPluralLabel(subcategory));
      rows.addAll(
        categoryAnimals.where(
          (animal) => animal['subcategory'] == subcategory.name,
        ),
      );
    }
    rows.addAll(
      categoryAnimals.where(
        (animal) => !category.subcategories.any(
          (subcategory) => subcategory.name == animal['subcategory'],
        ),
      ),
    );
  }
  return rows;
}
