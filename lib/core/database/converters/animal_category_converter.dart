import 'package:drift/drift.dart';

import '../enums/animal_category.dart';

class AnimalCategoryConverter extends TypeConverter<AnimalCategory, String> {
  const AnimalCategoryConverter();

  @override
  AnimalCategory fromSql(String fromDb) {
    return switch (fromDb) {
      'amphibian' => AnimalCategory.amphibian,
      'reptile' => AnimalCategory.reptile,
      'arachnid' => AnimalCategory.arachnid,
      'insect' => AnimalCategory.insect,
      'myriapod' => AnimalCategory.myriapod,
      'crustacean' => AnimalCategory.crustacean,
      'mollusc' => AnimalCategory.mollusc,
      'otherInvertebrate' => AnimalCategory.otherInvertebrate,
      'other' => AnimalCategory.other,
      _ => throw StateError(
        'Unsupported AnimalCategory database value: $fromDb',
      ),
    };
  }

  @override
  String toSql(AnimalCategory value) => value.name;
}

class AnimalSubcategoryConverter
    extends TypeConverter<AnimalSubcategory, String> {
  const AnimalSubcategoryConverter();

  @override
  AnimalSubcategory fromSql(String fromDb) {
    return switch (fromDb) {
      'snake' => AnimalSubcategory.snake,
      'lizard' => AnimalSubcategory.lizard,
      'turtle' => AnimalSubcategory.turtle,
      'frogOrToad' => AnimalSubcategory.frogOrToad,
      'newtOrSalamander' => AnimalSubcategory.newtOrSalamander,
      'tarantula' => AnimalSubcategory.tarantula,
      'otherSpider' => AnimalSubcategory.otherSpider,
      'scorpion' => AnimalSubcategory.scorpion,
      'whipSpiderOrWhipScorpion' => AnimalSubcategory.whipSpiderOrWhipScorpion,
      'beetle' => AnimalSubcategory.beetle,
      'cockroach' => AnimalSubcategory.cockroach,
      'mantis' => AnimalSubcategory.mantis,
      'grasshopperOrCricket' => AnimalSubcategory.grasshopperOrCricket,
      'millipede' => AnimalSubcategory.millipede,
      'centipede' => AnimalSubcategory.centipede,
      'isopod' => AnimalSubcategory.isopod,
      'crab' => AnimalSubcategory.crab,
      'snail' => AnimalSubcategory.snail,
      'other' => AnimalSubcategory.other,
      _ => throw StateError(
        'Unsupported AnimalSubcategory database value: $fromDb',
      ),
    };
  }

  @override
  String toSql(AnimalSubcategory value) => value.name;
}
