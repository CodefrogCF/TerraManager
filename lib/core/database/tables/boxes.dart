import 'package:drift/drift.dart';

import '../converters/box_archive_reason_converter.dart';
import '../converters/box_status_converter.dart';
import 'media_assets.dart';

@DataClassName('Box')
class Boxes extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get qrId => text().unique()();

  TextColumn get status => text()
      .withDefault(const Constant('active'))
      .map(const BoxStatusConverter())();

  TextColumn get archiveReason =>
      text().map(const BoxArchiveReasonConverter()).nullable()();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  TextColumn get archiveNotes => text().nullable()();

  TextColumn get name => text().nullable()();

  RealColumn get widthCm => real().nullable()();

  RealColumn get heightCm => real().nullable()();

  RealColumn get depthCm => real().nullable()();

  TextColumn get notes => text().nullable()();

  IntColumn get pictureMediaId =>
      integer().nullable().references(MediaAssets, #id)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
