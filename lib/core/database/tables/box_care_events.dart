import 'package:drift/drift.dart';

import '../enums/box_care_event_type.dart';
import 'boxes.dart';
import 'media_assets.dart';

class BoxCareEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get boxId =>
      integer().references(Boxes, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => textEnum<BoxCareEventType>()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get notes => text().nullable()();
  TextColumn get requestId => text().unique()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('substrateChange', 'cleaning', 'waterChange'))",
    'CHECK (revision > 0)',
  ];
}

class BoxCareEventAttachments extends Table {
  IntColumn get eventId =>
      integer().references(BoxCareEvents, #id, onDelete: KeyAction.cascade)();
  IntColumn get mediaAssetId => integer().references(MediaAssets, #id)();
  @override
  Set<Column> get primaryKey => {eventId, mediaAssetId};
}
