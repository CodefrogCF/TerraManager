enum BoxSortOrder {
  labelAscending,
  labelDescending,
  nameAscending,
  nameDescending,
  volumeAscending,
  volumeDescending,
}

enum BoxSortCriterion { label, name, volume }

extension BoxSortOrderSelection on BoxSortOrder {
  BoxSortCriterion get criterion => switch (this) {
    BoxSortOrder.labelAscending ||
    BoxSortOrder.labelDescending => BoxSortCriterion.label,
    BoxSortOrder.nameAscending ||
    BoxSortOrder.nameDescending => BoxSortCriterion.name,
    BoxSortOrder.volumeAscending ||
    BoxSortOrder.volumeDescending => BoxSortCriterion.volume,
  };

  BoxSortOrder get reversed => switch (this) {
    BoxSortOrder.labelAscending => BoxSortOrder.labelDescending,
    BoxSortOrder.labelDescending => BoxSortOrder.labelAscending,
    BoxSortOrder.nameAscending => BoxSortOrder.nameDescending,
    BoxSortOrder.nameDescending => BoxSortOrder.nameAscending,
    BoxSortOrder.volumeAscending => BoxSortOrder.volumeDescending,
    BoxSortOrder.volumeDescending => BoxSortOrder.volumeAscending,
  };
}

extension BoxSortCriterionDefaults on BoxSortCriterion {
  BoxSortOrder get defaultOrder => switch (this) {
    BoxSortCriterion.label => BoxSortOrder.labelAscending,
    BoxSortCriterion.name => BoxSortOrder.nameAscending,
    BoxSortCriterion.volume => BoxSortOrder.volumeAscending,
  };
}
