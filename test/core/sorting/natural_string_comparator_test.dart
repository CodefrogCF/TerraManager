import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/sorting/natural_string_comparator.dart';

void main() {
  test('sorts embedded numbers by value instead of digit text', () {
    final values = [
      'Animal 11',
      'Animal 2',
      'Animal 10',
      'Animal 1',
      'Animal 9',
      'Animal 02',
    ];

    values.sort(compareNaturalStrings);

    expect(values, [
      'Animal 1',
      'Animal 2',
      'Animal 02',
      'Animal 9',
      'Animal 10',
      'Animal 11',
    ]);
  });

  test('compares text without case sensitivity and remains deterministic', () {
    final values = ['beta', 'alpha', 'Alpha'];

    values.sort(compareNaturalStrings);

    expect(values, ['Alpha', 'alpha', 'beta']);
  });

  test('compares numeric chunks without integer overflow', () {
    final values = [
      'Box 999999999999999999999999999999',
      'Box 10',
      'Box 1000000000000000000000000000000',
    ];

    values.sort(compareNaturalStrings);

    expect(values, [
      'Box 10',
      'Box 999999999999999999999999999999',
      'Box 1000000000000000000000000000000',
    ]);
  });
}
