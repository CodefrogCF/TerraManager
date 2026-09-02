import 'package:drift/drift.dart';

import '../enums/birth_date_accuracy.dart';

class BirthDateAccuracyConverter
    extends TypeConverter<BirthDateAccuracy, String> {
  const BirthDateAccuracyConverter();

  @override
  BirthDateAccuracy fromSql(String fromDb) {
    return BirthDateAccuracy.values.byName(fromDb);
  }

  @override
  String toSql(BirthDateAccuracy value) {
    return value.name;
  }
}
