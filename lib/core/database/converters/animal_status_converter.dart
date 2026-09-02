import 'package:drift/drift.dart';

import '../enums/animal_status.dart';

class AnimalStatusConverter extends TypeConverter<AnimalStatus, String> {
  const AnimalStatusConverter();

  @override
  AnimalStatus fromSql(String fromDb) {
    return AnimalStatus.values.byName(fromDb);
  }

  @override
  String toSql(AnimalStatus value) {
    return value.name;
  }
}
