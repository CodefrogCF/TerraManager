import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/converters/sex_converter.dart';
import 'package:terramanager/core/database/enums/sex.dart';

void main() {
  const converter = SexConverter();

  test('encodes every Sex with a stable database value', () {
    expect(converter.toSql(Sex.male), 'male');
    expect(converter.toSql(Sex.female), 'female');
    expect(converter.toSql(Sex.other), 'other');
    expect(converter.toSql(Sex.unknown), 'unknown');
  });

  test('decodes existing and new database values', () {
    expect(converter.fromSql('male'), Sex.male);
    expect(converter.fromSql('female'), Sex.female);
    expect(converter.fromSql('unknown'), Sex.unknown);
    expect(converter.fromSql('other'), Sex.other);
  });

  test('rejects unsupported database values', () {
    expect(() => converter.fromSql('future-sex'), throwsStateError);
  });
}
