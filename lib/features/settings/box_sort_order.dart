enum BoxSortOrder {
  labelAscending,
  labelDescending,
  nameAscending,
  nameDescending,
}

enum BoxSortCriterion { label, name }

extension BoxSortOrderSelection on BoxSortOrder {
  BoxSortCriterion get criterion => switch (this) {
    BoxSortOrder.labelAscending ||
    BoxSortOrder.labelDescending => BoxSortCriterion.label,
    BoxSortOrder.nameAscending ||
    BoxSortOrder.nameDescending => BoxSortCriterion.name,
  };

  BoxSortOrder get reversed => switch (this) {
    BoxSortOrder.labelAscending => BoxSortOrder.labelDescending,
    BoxSortOrder.labelDescending => BoxSortOrder.labelAscending,
    BoxSortOrder.nameAscending => BoxSortOrder.nameDescending,
    BoxSortOrder.nameDescending => BoxSortOrder.nameAscending,
  };
}

extension BoxSortCriterionDefaults on BoxSortCriterion {
  BoxSortOrder get defaultOrder => switch (this) {
    BoxSortCriterion.label => BoxSortOrder.labelAscending,
    BoxSortCriterion.name => BoxSortOrder.nameAscending,
  };
}
