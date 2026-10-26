import '../../../core/database/enums/box_care_event_type.dart';
export '../../../core/database/enums/box_care_event_type.dart';

/// Box-owned care history; never an Animal history entry.
class BoxCareEntry {
  const BoxCareEntry({
    required this.id,
    required this.boxId,
    required this.type,
    required this.occurredAt,
    this.notes,
    this.mediaIds = const [],
    required this.revision,
    required this.requestId,
  });
  final int id;
  final int boxId;
  final BoxCareEventType type;
  final DateTime occurredAt;
  final String? notes;
  final List<int> mediaIds;
  final int revision;
  final String requestId;

  factory BoxCareEntry.fromJson(Map<String, dynamic> json) => BoxCareEntry(
    id: json['id'] as int,
    boxId: json['boxId'] as int,
    type: BoxCareEventType.values.byName(json['type'] as String),
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    notes: json['notes'] as String?,
    mediaIds: (json['mediaIds'] as List).cast<int>(),
    revision: json['revision'] as int,
    requestId: json['requestId'] as String,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'boxId': boxId,
    'type': type.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'notes': notes,
    'mediaIds': mediaIds,
    'revision': revision,
    'requestId': requestId,
  };
}
