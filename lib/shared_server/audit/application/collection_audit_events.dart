import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/audit/domain/audit_event.dart';
import 'package:terramanager/shared_server/collection/application/care_mutation_records.dart';

/// Extract identifiers and labels from server-owned records and replies.
/// Each grouped Feeding has its own affected-record event.
Future<List<AuditEvent>> collectionAuditEvents(
  AppDatabase database,
  AuditActor actor,
  String method,
  List<String> path,
  int status,
  Map<String, dynamic>? reply, {
  required CareMutationRecords? before,
  bool replayed = false,
}) async {
  if (path.isEmpty) return [];
  const roots = {
    'custom-field-templates': 'customFieldTemplate',
    'care-event-types': 'careEventType',
    'food-presets': 'foodPreset',
    'boxes': 'box',
    'animals': 'animal',
    'feedings': 'feeding',
    'media': 'media',
  };
  var type = roots[path.first];
  if (type == null) return [];
  String? numeric(String? text) => int.tryParse(text ?? '')?.toString();
  var target = path.length > 1 ? numeric(path[1]) : null;
  var operation = switch (method) {
    'POST' => 'create',
    'DELETE' => 'delete',
    'PUT' || 'PATCH' => 'update',
    _ => 'unknown',
  };
  if (path.length > 2) {
    final section = path[2];
    if (const {
      'archive',
      'restore',
      'duplicate',
      'move',
      'feeding-reminder',
    }.contains(section)) {
      operation = section;
    } else if (const {
      'pictures',
      'weights',
      'shedding',
      'care-events',
    }.contains(section)) {
      type = section == 'care-events'
          ? 'boxCareEvent'
          : section == 'pictures'
          ? 'media'
          : section == 'weights'
          ? 'weight'
          : section;
      target = path.length > 3 ? numeric(path[3]) : null;
      if (path.length > 4 && path[4] == 'primary') operation = 'set_primary';
    }
  }
  const keys = {
    'careEventType': 'careEventType',
    'customFieldTemplate': 'template',
    'foodPreset': 'preset',
  };
  if (keys.containsKey(type)) {
    final id = path.length > 1 ? path[1] : (reply?[keys[type]] as Map?)?['id'];
    target =
        id is String &&
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ).hasMatch(id)
        ? id
        : null;
    if (path.length == 2 && path[1] == 'order') operation = 'reorder';
  }
  final ids = <String>[];
  if (status < 400 && reply != null) {
    if (reply['feedings'] case final List<dynamic> feedings) {
      for (final record in feedings) {
        if (record is Map && record['id'] is int) ids.add('${record['id']}');
      }
    } else {
      for (final key in [
        'box',
        'animal',
        'feeding',
        'weight',
        'shedding',
        'careEvent',
        'picture',
      ]) {
        final record = reply[key];
        if (record is Map) {
          final value = key == 'picture' ? record['mediaId'] : record['id'];
          if (value is int) {
            ids.add('$value');
            break;
          }
        }
      }
      if (ids.isEmpty && reply['id'] is int) ids.add('${reply['id']}');
    }
  }
  final subject = _collectionSubject(type, reply, before);
  final feedingSubjects = type == 'feeding'
      ? await _feedingSubjects(database, target, reply, before?.feedingAnimalId)
      : const <String, AuditSubject>{};
  return [
    for (final id in ids.isEmpty ? <String?>[target] : ids)
      AuditEvent(
        actor: actor,
        action: '$type.$operation',
        recordType: type,
        recordId: id,
        subject: feedingSubjects[id] ?? subject,
        outcome: replayed
            ? 'replayed'
            : status < 400
            ? 'success'
            : 'rejected',
        statusCode: status,
      ),
  ];
}

AuditSubject? _collectionSubject(
  String type,
  Map<String, dynamic>? reply,
  CareMutationRecords? before,
) {
  final record = reply?[type];
  if (record is Map && record['id'] is int) {
    final id = record['id'] as int;
    if (type == 'box') return _boxSubject(id, record['name']);
    if (type == 'animal') {
      return _animalSubject(id, record['commonName'], record['latinName']);
    }
  }

  // Deletions and nested records use their pre-mutation Box or Animal.
  if (before?.box case final Box box) return _boxSubject(box.id, box.name);
  if (before?.animal case final Animal animal) {
    return _animalSubject(animal.id, animal.commonName, animal.latinName);
  }
  return null;
}

AuditSubject _boxSubject(int id, Object? name) =>
    AuditSubject('box', '$id', _label(name) ?? 'Box $id');

AuditSubject _animalSubject(int id, Object? name, Object? latinName) =>
    AuditSubject('animal', '$id', _label(name) ?? _label(latinName));

String? _label(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : String.fromCharCodes(text.runes.take(200));
}

Future<Map<String, AuditSubject>> _feedingSubjects(
  AppDatabase database,
  String? target,
  Map<String, dynamic>? reply,
  int? previousAnimalId,
) async {
  final owners = <String, int>{
    if (target != null && previousAnimalId != null) target: previousAnimalId,
  };
  final feedings = reply?['feedings'] as List? ?? [reply?['feeding']];
  for (final feeding in feedings) {
    if (feeding is Map && feeding['id'] is int && feeding['animalId'] is int) {
      owners['${feeding['id']}'] = feeding['animalId'] as int;
    }
  }
  if (owners.isEmpty) return {};

  final animals = database.animals;
  final query = database.selectOnly(animals)
    ..addColumns([animals.id, animals.commonName, animals.latinName])
    ..where(animals.id.isIn(owners.values.toSet()));
  final subjects = <int, AuditSubject>{};
  for (final row in await query.get()) {
    final id = row.read(animals.id)!;
    subjects[id] = _animalSubject(
      id,
      row.read(animals.commonName),
      row.read(animals.latinName),
    );
  }
  return {
    for (final entry in owners.entries)
      entry.key:
          subjects[entry.value] ??
          AuditSubject('animal', '${entry.value}', null),
  };
}
