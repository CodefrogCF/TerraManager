import 'package:drift/drift.dart';

import 'animals.dart';

@DataClassName('AnimalWeightEntry')
class AnimalWeightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get animalId =>
      integer().references(Animals, #id, onDelete: KeyAction.cascade)();

  RealColumn get weightGrams => real()();

  DateTimeColumn get measuredAt => dateTime()();
}
