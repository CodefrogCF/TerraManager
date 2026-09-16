import 'package:drift/drift.dart';

import 'boxes.dart';
import 'media_assets.dart';

@DataClassName('BoxPictureAssociation')
class BoxPictureAssociations extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get boxId =>
      integer().references(Boxes, #id, onDelete: KeyAction.cascade)();

  IntColumn get mediaAssetId =>
      integer().references(MediaAssets, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get capturedAt => dateTime()();

  IntColumn get sortOrder => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {mediaAssetId},
    {boxId, sortOrder},
  ];
}
