import 'package:drift/drift.dart';

import 'animals.dart';
import 'media_assets.dart';

@DataClassName('AnimalPictureAssociation')
class AnimalPictureAssociations extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get animalId =>
      integer().references(Animals, #id, onDelete: KeyAction.cascade)();

  IntColumn get mediaAssetId =>
      integer().references(MediaAssets, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get capturedAt => dateTime()();

  IntColumn get sortOrder => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {mediaAssetId},
    {animalId, sortOrder},
  ];
}
