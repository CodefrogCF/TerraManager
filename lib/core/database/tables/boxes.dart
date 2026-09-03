import 'package:drift/drift.dart';

import 'media_assets.dart';

@DataClassName('Box')
class Boxes extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get qrId => text().unique()();

  RealColumn get widthCm => real().nullable()();

  RealColumn get heightCm => real().nullable()();

  RealColumn get depthCm => real().nullable()();

  IntColumn get pictureMediaId =>
      integer().nullable().references(MediaAssets, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
