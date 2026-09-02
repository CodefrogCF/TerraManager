import 'package:drift/drift.dart';

@DataClassName('MediaAsset')
class MediaAssets extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get fileName => text()();

  TextColumn get mimeType => text()();

  BlobColumn get data => blob()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
