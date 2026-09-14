import '../../../core/database/validation/animal_environmental_limits.dart';
import '../../../l10n/generated/app_localizations.dart';

String? validateAnimalEnvironmentalInput({
  required AppLocalizations localizations,
  required String? value,
  required String pairedValue,
  required double minimumAllowed,
  required double maximumAllowed,
  required bool isMinimum,
}) {
  final trimmedValue = value?.trim();

  if (trimmedValue == null || trimmedValue.isEmpty) {
    return localizations.pleaseEnterValue;
  }

  final parsedValue = double.tryParse(trimmedValue);

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

  final parsedPair = double.tryParse(pairedValue.trim());

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
