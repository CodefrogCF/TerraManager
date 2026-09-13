import 'package:drift/drift.dart';

import '../enums/box_status.dart';

class BoxStatusConverter extends TypeConverter<BoxStatus, String> {
  const BoxStatusConverter();

  @override
  BoxStatus fromSql(String fromDb) => BoxStatus.values.byName(fromDb);

  @override
  String toSql(BoxStatus value) => value.name;
}
