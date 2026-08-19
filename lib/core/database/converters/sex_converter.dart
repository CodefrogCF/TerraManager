import 'package:drift/drift.dart';

enum Sex {
  male,
  female,
  unknown,
}

class SexConverter extends TypeConverter<Sex, String> {
  const SexConverter();

  @override
  Sex fromSql(String fromDb) {
    return Sex.values.byName(fromDb);
  }

  @override
  String toSql(Sex value) {
    return value.name;
  }
}