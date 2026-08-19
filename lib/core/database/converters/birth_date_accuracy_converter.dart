import 'package:drift/drift.dart';

enum BirthDateAccuracy {
  exact,
  monthKnown,
  yearKnown,
}

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