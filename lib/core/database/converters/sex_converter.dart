import 'package:drift/drift.dart';

import '../enums/sex.dart';

class SexConverter extends TypeConverter<Sex, String> {
  const SexConverter();

  @override
  Sex fromSql(String fromDb) {
    return switch (fromDb) {
      'male' => Sex.male,
      'female' => Sex.female,
      'unknown' => Sex.unknown,
      'other' => Sex.other,
      _ => throw StateError('Unsupported Sex database value: $fromDb'),
    };
  }

  @override
  String toSql(Sex value) {
    return switch (value) {
      Sex.male => 'male',
      Sex.female => 'female',
      Sex.unknown => 'unknown',
      Sex.other => 'other',
    };
  }
}
