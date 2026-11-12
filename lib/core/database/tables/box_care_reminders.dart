import 'package:drift/drift.dart';

import 'boxes.dart';

@DataClassName('BoxCareReminderRow')
class BoxCareReminders extends Table {
  IntColumn get boxId =>
      integer().references(Boxes, #id, onDelete: KeyAction.cascade)();
  TextColumn get typeKey => text()();
  TextColumn get dueOn => text().withLength(min: 10, max: 10)();
  IntColumn get intervalDays => integer().nullable()();
  TextColumn get lastCompletedOn => text().nullable()();
  TextColumn get revision => text()();

  @override
  Set<Column> get primaryKey => {boxId, typeKey};

  @override
  List<String> get customConstraints => [
    'CHECK (interval_days IS NULL OR interval_days BETWEEN 1 AND 36500)',
  ];
}
