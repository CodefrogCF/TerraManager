import 'package:drift/drift.dart';

import 'animals.dart';

@DataClassName('SheddingEvent')
class SheddingEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get animalId =>
      integer().references(Animals, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get shedAt => dateTime()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}
