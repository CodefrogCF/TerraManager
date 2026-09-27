/// Calendar dates are not instants. Preserve their written calendar components.
String? dateOnlyString(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime parseDateOnly(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|T| )').firstMatch(value);
  if (match == null) throw const FormatException('Expected a calendar date.');
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw const FormatException('Invalid calendar date.');
  }
  return date;
}
