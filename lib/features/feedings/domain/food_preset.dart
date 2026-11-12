import 'package:terramanager/features/custom_fields/domain/custom_field.dart';

class FoodPreset {
  const FoodPreset({
    required this.id,
    required this.name,
    required this.defaults,
    this.archived = false,
    this.revision = 1,
  });

  final String id;
  final String name;
  final Map<String, Object?> defaults;
  final bool archived;
  final int revision;

  factory FoodPreset.fromJson(Map<String, dynamic> json) {
    final preset = FoodPreset(
      id: json['id'] as String,
      name: CustomFieldTemplate.normalizeLabel(json['name'] as String),
      defaults: Map.unmodifiable(
        Map<String, Object?>.from(json['defaults'] as Map),
      ),
      archived: json['archived'] as bool? ?? false,
      revision: json['revision'] as int? ?? 1,
    );
    if (!CustomFieldTemplate.validId(preset.id) ||
        preset.revision < 1 ||
        preset.defaults.isEmpty ||
        preset.defaults.length > 1000 ||
        !preset.defaults.keys.every(CustomFieldTemplate.validId)) {
      throw ArgumentError('Invalid food preset.');
    }
    return preset;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'defaults': defaults,
    'archived': archived,
    'revision': revision,
  };

  Map<String, Object> validatedDefaults(
    Iterable<CustomFieldTemplate> templates,
  ) {
    final feedingFields = {
      for (final template in templates)
        if (template.target == CustomFieldTarget.feeding) template.id: template,
    };
    final ids = defaults.keys.toList()..sort();
    return {
      for (final id in ids)
        id:
            feedingFields[id]?.validate(defaults[id]) ??
            (throw ArgumentError('Invalid food preset default.')),
    };
  }
}
