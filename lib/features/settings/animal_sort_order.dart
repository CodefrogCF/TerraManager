enum AnimalSortOrder {
  createdOldestFirst,
  createdNewestFirst,
  displayNameAscending,
  displayNameDescending,
  ageOldestFirst,
  ageYoungestFirst,
  latestFeedingNewestFirst,
  latestFeedingOldestFirst,
}

enum AnimalSortCriterion { created, displayName, age, latestFeeding }

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
  };
}

extension AnimalSortCriterionDefaults on AnimalSortCriterion {
  AnimalSortOrder get defaultOrder => switch (this) {
    AnimalSortCriterion.created => AnimalSortOrder.createdOldestFirst,
    AnimalSortCriterion.displayName => AnimalSortOrder.displayNameAscending,
    AnimalSortCriterion.age => AnimalSortOrder.ageOldestFirst,
    AnimalSortCriterion.latestFeeding =>
      AnimalSortOrder.latestFeedingNewestFirst,
  };
}
