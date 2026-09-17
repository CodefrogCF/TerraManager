import 'package:flutter/material.dart';

import '../../../../core/database/validation/animal_environmental_limits.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../animal_environmental_validator.dart';

class AnimalRangeFields extends StatelessWidget {
  final String heading;
  final Key minimumKey;
  final Key maximumKey;
  final TextEditingController minimumController;
  final TextEditingController maximumController;
  final double minimumAllowed;
  final double maximumAllowed;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const AnimalRangeFields({
    super.key,
    required this.heading,
    required this.minimumKey,
    required this.maximumKey,
    required this.minimumController,
    required this.maximumController,
    required this.minimumAllowed,
    required this.maximumAllowed,
    required this.required,
    required this.enabled,
    this.onChanged,
  });

  factory AnimalRangeFields.temperature({
    Key? key,
    required String heading,
    required Key minimumKey,
    required Key maximumKey,
    required TextEditingController minimumController,
    required TextEditingController maximumController,
    required bool required,
    required bool enabled,
    ValueChanged<String>? onChanged,
  }) {
    return AnimalRangeFields(
      key: key,
      heading: heading,
      minimumKey: minimumKey,
      maximumKey: maximumKey,
      minimumController: minimumController,
      maximumController: maximumController,
      minimumAllowed: AnimalEnvironmentalLimits.minimumTemperatureCelsius,
      maximumAllowed: AnimalEnvironmentalLimits.maximumTemperatureCelsius,
      required: required,
      enabled: enabled,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  context,
                  key: minimumKey,
                  controller: minimumController,
                  label: context.l10n.minimum,
                  pairedController: maximumController,
                  isMinimum: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  context,
                  key: maximumKey,
                  controller: maximumController,
                  label: context.l10n.maximum,
                  pairedController: minimumController,
                  isMinimum: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required Key key,
    required TextEditingController controller,
    required String label,
    required TextEditingController pairedController,
    required bool isMinimum,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      validator: (value) => validateAnimalEnvironmentalInput(
        localizations: context.l10n,
        value: value,
        pairedValue: pairedController.text,
        minimumAllowed: minimumAllowed,
        maximumAllowed: maximumAllowed,
        isMinimum: isMinimum,
        required: required,
      ),
    );
  }
}
