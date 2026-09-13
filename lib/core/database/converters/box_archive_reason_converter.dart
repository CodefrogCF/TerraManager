import 'package:drift/drift.dart';

import '../enums/box_archive_reason.dart';

class BoxArchiveReasonConverter
    extends TypeConverter<BoxArchiveReason, String> {
  const BoxArchiveReasonConverter();

  @override
  BoxArchiveReason fromSql(String fromDb) =>
      BoxArchiveReason.values.byName(fromDb);

  @override
  String toSql(BoxArchiveReason value) => value.name;
}
