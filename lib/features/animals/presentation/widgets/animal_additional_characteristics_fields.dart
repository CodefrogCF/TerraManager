import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations_context.dart';
import '../animal_environmental_validator.dart';

class AnimalAdditionalCharacteristicsFields extends StatelessWidget {
  final bool expanded;
  final bool enabled;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;
  final TextEditingController originHabitatController;
  final TextEditingController weightController;
  final TextEditingController sheddingNotesController;
  final TextEditingController restOrDormancyPeriodsController;
  final TextEditingController nighttimeTemperatureController;

  const AnimalAdditionalCharacteristicsFields({
    super.key,
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.originHabitatController,
    required this.weightController,
    required this.sheddingNotesController,
    required this.restOrDormancyPeriodsController,
    required this.nighttimeTemperatureController,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          _optionalTextField(
            key: const Key('origin-habitat-field'),
            controller: originHabitatController,
            label: context.l10n.originHabitat,
          ),
          const SizedBox(height: 16),
          _optionalTextField(
            key: const Key('weight-field'),
            controller: weightController,
            label: context.l10n.weight,
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
            key: const Key('rest-or-dormancy-periods-field'),
            controller: restOrDormancyPeriodsController,
            label: context.l10n.restOrDormancyPeriods,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('nighttime-temperature-field'),
            controller: nighttimeTemperatureController,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            validator: (value) => validateOptionalAnimalTemperatureInput(
              localizations: context.l10n,
              value: value,
            ),
            decoration: InputDecoration(
              labelText: context.l10n.nighttimeTemperatureCelsius,
            ),
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
