import 'package:drift/drift.dart';

import '../enums/box_care_event_type.dart';
import 'boxes.dart';
import 'care_event_types.dart';

class BoxCareEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get boxId =>
      integer().references(Boxes, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => textEnum<BoxCareEventType>()();
  TextColumn get customTypeId =>
      text().nullable().references(CareEventTypes, #id)();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get notes => text().nullable()();
  TextColumn get requestId => text().unique()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('substrateChange', 'cleaning', 'waterChange', 'custom'))",
    "CHECK ((type = 'custom' AND custom_type_id IS NOT NULL) OR (type <> 'custom' AND custom_type_id IS NULL))",
    'CHECK (revision > 0)',
  ];
}
