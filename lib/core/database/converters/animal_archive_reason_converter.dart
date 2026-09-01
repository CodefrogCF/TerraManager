import 'package:drift/drift.dart';

import '../enums/animal_archive_reason.dart';

class AnimalArchiveReasonConverter
    extends TypeConverter<AnimalArchiveReason, String> {
  const AnimalArchiveReasonConverter();

  @override
  AnimalArchiveReason fromSql(String fromDb) {
    return AnimalArchiveReason.values.byName(fromDb);
  }

  @override
  String toSql(AnimalArchiveReason value) {
    return value.name;
  }
}