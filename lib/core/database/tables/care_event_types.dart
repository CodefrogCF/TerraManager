import 'package:drift/drift.dart';

@DataClassName('CareEventTypeRow')
class CareEventTypes extends Table {
  TextColumn get id => text()();
  TextColumn get label => text().withLength(min: 1, max: 80)();
  TextColumn get labelKey => text().unique()();
  IntColumn get sortOrder => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK (revision > 0)',
    'CHECK (sort_order >= 0)',
  ];
}
