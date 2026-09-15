enum AnimalSortOrder {
  createdOldestFirst,
  createdNewestFirst,
  displayNameAscending,
  displayNameDescending,
  ageOldestFirst,
  ageYoungestFirst,
  latestFeedingNewestFirst,
  latestFeedingOldestFirst,
  categoryAscending,
  categoryDescending,
}

enum AnimalSortCriterion { created, displayName, age, latestFeeding, category }

extension AnimalSortOrderSelection on AnimalSortOrder {
  AnimalSortCriterion get criterion => switch (this) {
    AnimalSortOrder.createdOldestFirst ||
    AnimalSortOrder.createdNewestFirst => AnimalSortCriterion.created,
    AnimalSortOrder.displayNameAscending ||
    AnimalSortOrder.displayNameDescending => AnimalSortCriterion.displayName,
    AnimalSortOrder.ageOldestFirst ||
    AnimalSortOrder.ageYoungestFirst => AnimalSortCriterion.age,
    AnimalSortOrder.latestFeedingNewestFirst ||
    AnimalSortOrder.latestFeedingOldestFirst =>
      AnimalSortCriterion.latestFeeding,
    AnimalSortOrder.categoryAscending ||
    AnimalSortOrder.categoryDescending => AnimalSortCriterion.category,
  };

  AnimalSortOrder get reversed => switch (this) {
    AnimalSortOrder.createdOldestFirst => AnimalSortOrder.createdNewestFirst,
    AnimalSortOrder.createdNewestFirst => AnimalSortOrder.createdOldestFirst,
    AnimalSortOrder.displayNameAscending =>
      AnimalSortOrder.displayNameDescending,
    AnimalSortOrder.displayNameDescending =>
      AnimalSortOrder.displayNameAscending,
    AnimalSortOrder.ageOldestFirst => AnimalSortOrder.ageYoungestFirst,
    AnimalSortOrder.ageYoungestFirst => AnimalSortOrder.ageOldestFirst,
    AnimalSortOrder.latestFeedingNewestFirst =>
      AnimalSortOrder.latestFeedingOldestFirst,
    AnimalSortOrder.latestFeedingOldestFirst =>
      AnimalSortOrder.latestFeedingNewestFirst,
    AnimalSortOrder.categoryAscending => AnimalSortOrder.categoryDescending,
    AnimalSortOrder.categoryDescending => AnimalSortOrder.categoryAscending,
  };
}

extension AnimalSortCriterionDefaults on AnimalSortCriterion {
  AnimalSortOrder get defaultOrder => switch (this) {
    AnimalSortCriterion.created => AnimalSortOrder.createdOldestFirst,
    AnimalSortCriterion.displayName => AnimalSortOrder.displayNameAscending,
    AnimalSortCriterion.age => AnimalSortOrder.ageOldestFirst,
    AnimalSortCriterion.latestFeeding =>
      AnimalSortOrder.latestFeedingNewestFirst,
    AnimalSortCriterion.category => AnimalSortOrder.categoryAscending,
  };
}
