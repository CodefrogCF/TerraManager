import 'package:drift/drift.dart';

import 'animals.dart';
import 'boxes.dart';

@DataClassName('CustomFieldTemplateRow')
class CustomFieldTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get target => text()();
  TextColumn get type => text()();
  TextColumn get label => text().withLength(min: 1, max: 80)();
  TextColumn get labelKey => text()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {target, labelKey},
  ];
  @override
  List<String> get customConstraints => [
    "CHECK (target IN ('animal','box'))",
    "CHECK (type IN ('text','number','date','boolean'))",
    'CHECK (revision>0)',
  ];
}

@DataClassName('CustomFieldValueRow')
class CustomFieldValues extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get templateId => text().references(CustomFieldTemplates, #id)();
  IntColumn get animalId => integer().nullable().references(
    Animals,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get boxId => integer().nullable().references(
    Boxes,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get valueJson => text()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  @override
  List<Set<Column>> get uniqueKeys => [
    {animalId, templateId},
    {boxId, templateId},
  ];
  @override
  List<String> get customConstraints => [
    'CHECK ((animal_id IS NOT NULL) != (box_id IS NOT NULL))',
    'CHECK (revision>0)',
  ];
}
