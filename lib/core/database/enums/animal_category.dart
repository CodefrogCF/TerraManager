enum AnimalCategory {
  amphibian,
  reptile,
  arachnid,
  insect,
  myriapod,
  crustacean,
  mollusc,
  otherInvertebrate,
  other,
}

enum AnimalSubcategory {
  snake,
  lizard,
  turtle,
  frogOrToad,
  newtOrSalamander,
  tarantula,
  otherSpider,
  scorpion,
  whipSpiderOrWhipScorpion,
  beetle,
  cockroach,
  mantis,
  grasshopperOrCricket,
  millipede,
  centipede,
  isopod,
  crab,
  snail,
  other,
}

extension AnimalCategoryTaxonomy on AnimalCategory {
  List<AnimalSubcategory> get subcategories => switch (this) {
    AnimalCategory.amphibian => const [
      AnimalSubcategory.frogOrToad,
      AnimalSubcategory.newtOrSalamander,
      AnimalSubcategory.other,
    ],
    AnimalCategory.reptile => const [
      AnimalSubcategory.snake,
      AnimalSubcategory.lizard,
      AnimalSubcategory.turtle,
      AnimalSubcategory.other,
    ],
    AnimalCategory.arachnid => const [
      AnimalSubcategory.tarantula,
      AnimalSubcategory.otherSpider,
      AnimalSubcategory.scorpion,
      AnimalSubcategory.whipSpiderOrWhipScorpion,
      AnimalSubcategory.other,
    ],
    AnimalCategory.insect => const [
      AnimalSubcategory.beetle,
      AnimalSubcategory.cockroach,
      AnimalSubcategory.mantis,
      AnimalSubcategory.grasshopperOrCricket,
      AnimalSubcategory.other,
    ],
    AnimalCategory.myriapod => const [
      AnimalSubcategory.millipede,
      AnimalSubcategory.centipede,
      AnimalSubcategory.other,
    ],
    AnimalCategory.crustacean => const [
      AnimalSubcategory.isopod,
      AnimalSubcategory.crab,
      AnimalSubcategory.other,
    ],
    AnimalCategory.mollusc => const [
      AnimalSubcategory.snail,
      AnimalSubcategory.other,
    ],
    AnimalCategory.otherInvertebrate || AnimalCategory.other => const [],
  };

  bool supports(AnimalSubcategory? subcategory) {
    return subcategory == null || subcategories.contains(subcategory);
  }
}
