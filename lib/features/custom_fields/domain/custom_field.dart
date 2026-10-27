import 'dart:convert';

enum CustomFieldTarget { animal, box }

enum CustomFieldType { text, number, date, boolean }

class CustomFieldConflict extends StateError {
  CustomFieldConflict() : super('Custom fields changed. Reload before saving.');
}

/// Stable, collection-owned definition. Kind and target cannot be changed.
class CustomFieldTemplate {
  const CustomFieldTemplate({
    required this.id,
    required this.target,
    required this.type,
    required this.label,
    this.hidden = false,
    this.archived = false,
    this.revision = 1,
  });
  final String id;
  final CustomFieldTarget target;
  final CustomFieldType type;
  final String label;
  final bool hidden, archived;
  final int revision;
  static bool validId(String id) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(id);
  static String normalizeLabel(String label) {
    if (RegExp(
      r'[\x00-\x1f\x7f-\x9f\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]',
    ).hasMatch(label)) {
      throw ArgumentError('Invalid field label.');
    }
    final clean = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty || clean.length > 80) {
      throw ArgumentError('Invalid field label.');
    }
    return clean;
  }

  factory CustomFieldTemplate.fromJson(Map<String, dynamic> json) {
    final result = CustomFieldTemplate(
      id: json['id'] as String,
      target: CustomFieldTarget.values.byName(json['target'] as String),
      type: CustomFieldType.values.byName(json['type'] as String),
      label: normalizeLabel(json['label'] as String),
      hidden: json['hidden'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      revision: json['revision'] as int? ?? 1,
    );
    if (!validId(result.id) || result.revision < 1) {
      throw ArgumentError('Invalid field definition.');
    }
    return result;
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'target': target.name,
    'type': type.name,
    'label': label,
    'hidden': hidden,
    'archived': archived,
    'revision': revision,
  };
  Object? validate(Object? value) {
    if (value == null) return null;
    switch (type) {
      case CustomFieldType.text:
        if (value is! String || value.length > 10000) {
          throw ArgumentError('Invalid text.');
        }
        return value.trim().isEmpty ? null : value;
      case CustomFieldType.number:
        if (value is! num || !value.isFinite) {
          throw ArgumentError('Invalid number.');
        }
        return value.toDouble();
      case CustomFieldType.boolean:
        if (value is! bool) throw ArgumentError('Invalid boolean.');
        return value;
      case CustomFieldType.date:
        if (value is! String ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
          throw ArgumentError('Invalid date.');
        }
        final parts = value.split('-').map(int.parse).toList();
        final date = DateTime(parts[0], parts[1], parts[2]);
        if (parts[0] < 1 ||
            date.year != parts[0] ||
            date.month != parts[1] ||
            date.day != parts[2]) {
          throw ArgumentError('Invalid date.');
        }
        return value;
    }
  }
}

class CustomFieldValue {
  const CustomFieldValue(this.templateId, this.value, {this.revision = 1});
  final String templateId;
  final Object? value;
  final int revision;
  factory CustomFieldValue.fromJson(Map<String, dynamic> json) =>
      CustomFieldValue(
        json['templateId'] as String,
        json['value'],
        revision: json['revision'] as int? ?? 1,
      );
  Map<String, dynamic> toJson() => {
    'templateId': templateId,
    'value': value,
    'revision': revision,
  };
}

class CustomFieldsSnapshot {
  const CustomFieldsSnapshot({
    required this.templates,
    required this.values,
    this.revision,
    this.active = true,
  });
  final List<CustomFieldTemplate> templates;
  final List<CustomFieldValue> values;
  final String? revision;
  final bool active;
  Object? value(String id) =>
      values.where((v) => v.templateId == id).firstOrNull?.value;
  factory CustomFieldsSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => CustomFieldsSnapshot(
    templates: (json['templates'] as List)
        .map(
          (v) =>
              CustomFieldTemplate.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList(),
    values: (json['values'] as List)
        .map(
          (v) => CustomFieldValue.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList(),
    revision: json['revision'] as String?,
    active: json['active'] as bool,
  );
  Map<String, dynamic> toJson() => {
    'templates': templates.map((t) => t.toJson()).toList(),
    'values': values.map((v) => v.toJson()).toList(),
    'revision': revision,
    'active': active,
  };
}

/// Only dirty, visible fields are changed. Omitted values are preserved.
class CustomFieldPatch {
  const CustomFieldPatch({
    required this.expectedRevision,
    required this.updates,
  });
  final String? expectedRevision;
  final List<({String id, int templateRevision, Object? value})> updates;
  factory CustomFieldPatch.fromJson(Object? raw) {
    if (raw is! Map ||
        raw.keys.any((k) => k != 'expectedRevision' && k != 'updates') ||
        raw['updates'] is! List ||
        (raw['expectedRevision'] != null &&
            raw['expectedRevision'] is! String)) {
      throw ArgumentError('Invalid custom fields.');
    }
    final updates = <({String id, int templateRevision, Object? value})>[];
    for (final entry in raw['updates'] as List) {
      if (entry is! Map ||
          entry.length != 3 ||
          !entry.containsKey('value') ||
          entry['templateId'] is! String ||
          entry['templateRevision'] is! int) {
        throw ArgumentError('Invalid custom field update.');
      }
      updates.add((
        id: entry['templateId'] as String,
        templateRevision: entry['templateRevision'] as int,
        value: entry['value'],
      ));
    }
    if (updates.isEmpty ||
        updates.map((e) => e.id).toSet().length != updates.length ||
        updates.length > 1000) {
      throw ArgumentError('Invalid custom field update.');
    }
    return CustomFieldPatch(
      expectedRevision: raw['expectedRevision'] as String?,
      updates: updates,
    );
  }
  Map<String, dynamic> toJson() => {
    'expectedRevision': expectedRevision,
    'updates': [
      for (final u in updates)
        {
          'templateId': u.id,
          'templateRevision': u.templateRevision,
          'value': u.value,
        },
    ],
  };
}

bool sameFieldValue(Object? a, Object? b) =>
    a is num && b is num ? a == b : jsonEncode(a) == jsonEncode(b);
