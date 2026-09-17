import '../../../core/database/validation/animal_environmental_limits.dart';
import '../../../l10n/generated/app_localizations.dart';

double? parseAnimalDecimal(String? value) {
  final normalized = value?.trim().replaceAll(',', '.');
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String? validateAnimalEnvironmentalInput({
  required AppLocalizations localizations,
  required String? value,
  required String pairedValue,
  required double minimumAllowed,
  required double maximumAllowed,
  required bool isMinimum,
  bool required = true,
}) {
  final trimmedValue = value?.trim();

  if (trimmedValue == null || trimmedValue.isEmpty) {
    return required ? localizations.pleaseEnterValue : null;
  }

  final parsedValue = parseAnimalDecimal(trimmedValue);

  if (parsedValue == null || !parsedValue.isFinite) {
    return localizations.pleaseEnterValidNumber;
  }

  if (!AnimalEnvironmentalLimits.isWithinRange(
    parsedValue,
    minimumAllowed,
    maximumAllowed,
  )) {
    return localizations.environmentalValueOutOfRange(
      _formatLimit(minimumAllowed),
      _formatLimit(maximumAllowed),
    );
  }

  final parsedPair = parseAnimalDecimal(pairedValue);

  if (parsedPair == null ||
      !AnimalEnvironmentalLimits.isWithinRange(
        parsedPair,
        minimumAllowed,
        maximumAllowed,
      )) {
    return null;
  }

  if (isMinimum && parsedValue > parsedPair) {
    return localizations.minimumMustNotExceedMaximum;
  }

  if (!isMinimum && parsedValue < parsedPair) {
    return localizations.maximumMustNotBeBelowMinimum;
  }

  return null;
}

String _formatLimit(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toString();
}

String? validateOptionalAnimalTemperatureInput({
  required AppLocalizations localizations,
  required String? value,
}) {
  final trimmedValue = value?.trim();
  if (trimmedValue == null || trimmedValue.isEmpty) {
    return null;
  }

  final parsedValue = parseAnimalDecimal(trimmedValue);
  if (parsedValue == null || !parsedValue.isFinite) {
    return localizations.pleaseEnterValidNumber;
  }

  if (!AnimalEnvironmentalLimits.isWithinRange(
    parsedValue,
    AnimalEnvironmentalLimits.minimumTemperatureCelsius,
    AnimalEnvironmentalLimits.maximumTemperatureCelsius,
  )) {
    return localizations.environmentalValueOutOfRange(
      _formatLimit(AnimalEnvironmentalLimits.minimumTemperatureCelsius),
      _formatLimit(AnimalEnvironmentalLimits.maximumTemperatureCelsius),
    );
  }

  return null;
}
