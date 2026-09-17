class AnimalWeightParser {
  const AnimalWeightParser._();

  static double? parseInput(String? value) {
    final normalized = value?.trim().replaceAll(',', '.');
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  /// Converts only values that explicitly name grams. Unitless or other
  /// free-form legacy values stay untouched so migration never guesses.
  static double? parseUnambiguousLegacyGrams(String? value) {
    final match = RegExp(
      r'^\s*(\d+(?:[.,]\d+)?)\s*(?:g|gram|grams|gramm)\s*$',
      caseSensitive: false,
    ).firstMatch(value ?? '');
    if (match == null) {
      return null;
    }
    return parseInput(match.group(1));
  }

  static bool equivalent(double left, double right) =>
      (left - right).abs() < 0.000001;
}
