import 'package:drift/drift.dart';

import 'animals.dart';

class FeedingEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get animalId =>
      integer().references(Animals, #id)();

  DateTimeColumn get fedAt =>
      dateTime()();

  TextColumn get notes =>
      text().nullable()();
}