enum ArchiveSortOrder {
  archivedNewestFirst,
  archivedOldestFirst,
  nameAscending,
  nameDescending,
}

enum ArchiveSortCriterion { archivedAt, name }

extension ArchiveSortOrderSelection on ArchiveSortOrder {
  ArchiveSortCriterion get criterion => switch (this) {
    ArchiveSortOrder.archivedNewestFirst ||
    ArchiveSortOrder.archivedOldestFirst => ArchiveSortCriterion.archivedAt,

    ArchiveSortOrder.nameAscending ||
    ArchiveSortOrder.nameDescending => ArchiveSortCriterion.name,
  };

  ArchiveSortOrder get reversed => switch (this) {
    ArchiveSortOrder.archivedNewestFirst =>
      ArchiveSortOrder.archivedOldestFirst,

    ArchiveSortOrder.archivedOldestFirst =>
      ArchiveSortOrder.archivedNewestFirst,

    ArchiveSortOrder.nameAscending => ArchiveSortOrder.nameDescending,

    ArchiveSortOrder.nameDescending => ArchiveSortOrder.nameAscending,
  };
}

extension ArchiveSortCriterionDefaults on ArchiveSortCriterion {
  ArchiveSortOrder get defaultOrder => switch (this) {
    ArchiveSortCriterion.archivedAt => ArchiveSortOrder.archivedNewestFirst,

    ArchiveSortCriterion.name => ArchiveSortOrder.nameAscending,
  };
}
