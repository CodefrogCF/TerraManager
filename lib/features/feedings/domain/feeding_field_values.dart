import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:terramanager/features/custom_fields/domain/custom_field.dart';

/// Captures the definition and value used when a Feeding was saved.
class FeedingFieldValue {
  const FeedingFieldValue(this.template, this.value);

  final CustomFieldTemplate template;
  final Object value;

  factory FeedingFieldValue.fromJson(Map<String, dynamic> json) {
    final template = CustomFieldTemplate.fromJson({
      'id': json['templateId'],
      'target': 'feeding',
      'label': json['label'],
      'type': json['type'],
      // The saved option is independent of later changes to its template.
      if (json['type'] == 'choice') 'options': [json['value']],
    });
    final value = template.validate(json['value']);
    if (value == null) throw ArgumentError('A saved Feeding field is empty.');
    return FeedingFieldValue(template, value);
  }

  Map<String, Object> toJson() => {
    'templateId': template.id,
    'label': template.label,
    'type': template.type.name,
    'value': value,
  };
}

List<FeedingFieldValue> readFeedingFieldValues(Object? json) {
  if (json == null) return const [];
  if (json is! List || json.length > 1000) {
    throw ArgumentError('Invalid Feeding fields.');
  }
  final values = <FeedingFieldValue>[];
  final ids = <String>{};
  for (final item in json) {
    final value = FeedingFieldValue.fromJson(
      Map<String, dynamic>.from(item as Map),
    );
    if (!ids.add(value.template.id)) {
      throw ArgumentError('Duplicate Feeding field.');
    }
    values.add(value);
  }
  return values;
}

List<FeedingFieldValue> decodeFeedingFieldValues(String? json) =>
    readFeedingFieldValues(json == null ? null : jsonDecode(json));

List<Map<String, Object>> feedingFieldValuesJson(
  Iterable<FeedingFieldValue> values,
) => values.map((value) => value.toJson()).toList();

String? encodeFeedingFieldValues(List<FeedingFieldValue> values) =>
    values.isEmpty ? null : jsonEncode(feedingFieldValuesJson(values));

String feedingFieldRevision(List<FeedingFieldValue> values) => sha256
    .convert(utf8.encode(jsonEncode(feedingFieldValuesJson(values))))
    .toString();

CustomFieldsSnapshot feedingFieldsSnapshot(
  List<CustomFieldTemplate> templates, {
  List<FeedingFieldValue>? saved,
}) => CustomFieldsSnapshot(
  templates: [
    for (final type in [CustomFieldType.integer, CustomFieldType.choice])
      ...templates.where((template) => template.type == type),
    ...templates.where(
      (template) =>
          template.type != CustomFieldType.integer &&
          template.type != CustomFieldType.choice,
    ),
  ],
  values: [
    for (final field in saved ?? const <FeedingFieldValue>[])
      CustomFieldValue(field.template.id, field.value),
  ],
  revision: saved == null ? null : feedingFieldRevision(saved),
);
