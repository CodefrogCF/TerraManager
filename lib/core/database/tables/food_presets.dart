import 'package:drift/drift.dart';

@DataClassName('FoodPresetRow')
class FoodPresets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get nameKey => text().unique()();
  TextColumn get defaultsJson => text()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (revision > 0)'];
}
