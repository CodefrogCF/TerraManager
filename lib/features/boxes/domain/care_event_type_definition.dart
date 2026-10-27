/// Collection-owned metadata. IDs remain stable across rename, archive and backup.
class CareEventTypeDefinition {
  const CareEventTypeDefinition({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.archived,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String label;
  final int sortOrder;
  final bool archived;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  static bool validId(String id) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(id);
  static String normalizeLabel(String value) {
    if (RegExp(
      r'[\x00-\x1f\x7f-\x9f\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]',
    ).hasMatch(value)) {
      throw ArgumentError('Invalid care type label.');
    }
    final label = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (label.isEmpty ||
        label.length > 80 ||
        const {
          'substrate change',
          'cleaning',
          'water change',
          'substratwechsel',
          'reinigung',
          'wasserwechsel',
        }.contains(label.toLowerCase())) {
      throw ArgumentError('Invalid care type label.');
    }
    return label;
  }

  static String labelKey(String value) => normalizeLabel(value).toLowerCase();

  factory CareEventTypeDefinition.fromJson(Map<String, dynamic> json) =>
      CareEventTypeDefinition(
        id: json['id'] as String,
        label: json['label'] as String,
        sortOrder: json['sortOrder'] as int,
        archived: json['archived'] as bool,
        revision: json['revision'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'sortOrder': sortOrder,
    'archived': archived,
    'revision': revision,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
