import 'package:flutter/material.dart';

import '../../../../core/database/validation/animal_weight_parser.dart';
import '../../../../l10n/app_localizations_context.dart';
import 'animal_range_fields.dart';

class AnimalAdditionalCharacteristicsFields extends StatelessWidget {
  final bool expanded;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;
  final Widget birthDateField;
  final Widget birthDateAccuracyField;
  final Widget sexField;
  final TextEditingController weightController;
  final String? legacyWeight;
  final TextEditingController originHabitatController;
  final TextEditingController nighttimeTemperatureMinController;
  final TextEditingController nighttimeTemperatureMaxController;
  final TextEditingController restOrDormancyPeriodsController;
  final TextEditingController sheddingNotesController;
  final TextEditingController notesController;

  const AnimalAdditionalCharacteristicsFields({
    super.key,
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.birthDateField,
    required this.birthDateAccuracyField,
    required this.sexField,
    required this.weightController,
    required this.originHabitatController,
    required this.nighttimeTemperatureMinController,
    required this.nighttimeTemperatureMaxController,
    required this.restOrDormancyPeriodsController,
    required this.sheddingNotesController,
    required this.notesController,
    this.legacyWeight,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedLegacyWeight = legacyWeight?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('additional-characteristics-button'),
          onPressed: enabled ? onToggle : null,
          icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          label: Text(context.l10n.additionalCharacteristics),
        ),
        if (expanded) ...[
          const SizedBox(height: 16),
          birthDateField,
          const SizedBox(height: 16),
          birthDateAccuracyField,
          const SizedBox(height: 16),
          sexField,
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('weight-field'),
            controller: weightController,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: context.l10n.weightGrams,
              helperText:
                  normalizedLegacyWeight == null ||
                      normalizedLegacyWeight.isEmpty
                  ? null
                  : context.l10n.legacyWeightValue(normalizedLegacyWeight),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return null;
              }
              return AnimalWeightParser.parseInput(trimmed) == null
                  ? context.l10n.pleaseEnterPositiveNumber
                  : null;
            },
          ),
          const SizedBox(height: 16),
          _optionalTextField(
            key: const Key('origin-habitat-field'),
            controller: originHabitatController,
            label: context.l10n.originHabitat,
          ),
          const SizedBox(height: 16),
          AnimalRangeFields.temperature(
            key: const Key('nighttime-temperature-range'),
            heading: context.l10n.nighttimeTemperatureCelsius,
            minimumKey: const Key('nighttime-temperature-min-field'),
            maximumKey: const Key('nighttime-temperature-max-field'),
            minimumController: nighttimeTemperatureMinController,
            maximumController: nighttimeTemperatureMaxController,
            required: false,
            enabled: enabled,
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
          _optionalTextField(
            key: const Key('rest-or-dormancy-periods-field'),
            controller: restOrDormancyPeriodsController,
            label: context.l10n.restOrDormancyPeriods,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _optionalTextField(
            key: const Key('shedding-notes-field'),
            controller: sheddingNotesController,
            label: context.l10n.sheddingNotes,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _optionalTextField(
            key: const Key('notes-field'),
            controller: notesController,
            label: context.l10n.notes,
            maxLines: 5,
          ),
        ],
      ],
    );
  }

  Widget _optionalTextField({
    required Key key,
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
