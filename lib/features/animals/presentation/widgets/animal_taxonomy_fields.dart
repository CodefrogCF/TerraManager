import 'package:flutter/material.dart';

import '../../../../core/database/enums/animal_category.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';

typedef AnimalTaxonomyChanged = void Function(
  AnimalCategory category,
  AnimalSubcategory? subcategory,
);

class AnimalTaxonomyFields extends StatelessWidget {
  final AnimalCategory category;
  final AnimalSubcategory? subcategory;
  final bool enabled;
  final AnimalTaxonomyChanged onChanged;

  const AnimalTaxonomyFields({
    super.key,
    required this.category,
    required this.subcategory,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final subcategories = category.subcategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AnimalCategory>(
          key: const Key('animal-category-field'),
          initialValue: category,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.l10n.animalCategory),
          items: AnimalCategory.values
              .map(
                (value) => DropdownMenuItem<AnimalCategory>(
                  value: value,
                  child: Text(context.l10n.animalCategoryLabel(value)),
                ),
              )
              .toList(growable: false),
          onChanged: enabled
              ? (value) {
                  if (value == null) {
                    return;
                  }
                  onChanged(
                    value,
                    value.supports(subcategory) ? subcategory : null,
                  );
                }
              : null,
        ),
        if (subcategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Semantics(
            label: context.l10n.animalSubcategory,
            child: DropdownButtonFormField<AnimalSubcategory?>(
              key: ValueKey<String>(
                'animal-subcategory-field-${category.name}',
              ),
              initialValue: category.supports(subcategory) ? subcategory : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.animalSubcategory,
              ),
              items: [
                DropdownMenuItem<AnimalSubcategory?>(
                  value: null,
                  child: Text(context.l10n.notSpecified),
                ),
                ...subcategories.map(
                  (value) => DropdownMenuItem<AnimalSubcategory?>(
                    value: value,
                    child: Text(context.l10n.animalSubcategoryLabel(value)),
                  ),
                ),
              ],
              onChanged: enabled
                  ? (value) {
                      onChanged(category, value);
                    }
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}
