import 'package:drift/drift.dart';

@DataClassName('Box')
class Boxes extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get qrId => text().unique()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}