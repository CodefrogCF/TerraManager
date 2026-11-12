import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:terramanager/features/feedings/domain/animal_rest_period.dart';

class AnimalRestPeriodConverter
    extends TypeConverter<AnimalRestPeriod, String> {
  const AnimalRestPeriodConverter();

  @override
  AnimalRestPeriod fromSql(String fromDb) =>
      AnimalRestPeriod.fromJson(jsonDecode(fromDb))!;

  @override
  String toSql(AnimalRestPeriod value) => jsonEncode(value.toJson());
}
