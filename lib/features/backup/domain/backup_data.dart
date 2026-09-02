class BackupData {
  final List<BackupBox> boxes;
  final List<BackupAnimal> animals;
  final List<BackupFeedingEvent> feedingEvents;

  const BackupData({
    required this.boxes,
    required this.animals,
    required this.feedingEvents,
  });

  Map<String, dynamic> toJson() {
    return {
      'boxes': boxes.map((box) => box.toJson()).toList(),
      'animals': animals.map((animal) => animal.toJson()).toList(),
      'feedingEvents': feedingEvents
          .map((feeding) => feeding.toJson())
          .toList(),
    };
  }

  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      boxes: (json['boxes'] as List<dynamic>)
          .map((item) => BackupBox.fromJson(item as Map<String, dynamic>))
          .toList(),
      animals: (json['animals'] as List<dynamic>)
          .map((item) => BackupAnimal.fromJson(item as Map<String, dynamic>))
          .toList(),
      feedingEvents: (json['feedingEvents'] as List<dynamic>)
          .map(
            (item) => BackupFeedingEvent.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class BackupBox {
  final int id;
  final String qrId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BackupBox({
    required this.id,
    required this.qrId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'qrId': qrId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BackupBox.fromJson(Map<String, dynamic> json) {
    return BackupBox(
      id: json['id'] as int,
      qrId: json['qrId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class BackupAnimal {
  final int id;
  final int? boxId;

  final String status;

  final String commonName;
  final String latinName;

  final String? sex;

  final DateTime? birthDate;
  final String? birthDateAccuracy;

  final double tempMin;
  final double tempMax;

  final double humidityMin;
  final double humidityMax;

  final String? pictureMediaPath;
  final String? notes;

  final String? archiveReason;
  final DateTime? archivedAt;
  final String? archiveNotes;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BackupAnimal({
    required this.id,
    required this.boxId,
    required this.status,
    required this.commonName,
    required this.latinName,
    required this.sex,
    required this.birthDate,
    required this.birthDateAccuracy,
    required this.tempMin,
    required this.tempMax,
    required this.humidityMin,
    required this.humidityMax,
    required this.pictureMediaPath,
    required this.notes,
    required this.archiveReason,
    required this.archivedAt,
    required this.archiveNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boxId': boxId,
      'status': status,
      'commonName': commonName,
      'latinName': latinName,
      'sex': sex,
      'birthDate': birthDate?.toIso8601String(),
      'birthDateAccuracy': birthDateAccuracy,
      'tempMin': tempMin,
      'tempMax': tempMax,
      'humidityMin': humidityMin,
      'humidityMax': humidityMax,
      'pictureMediaPath': pictureMediaPath,
      'notes': notes,
      'archiveReason': archiveReason,
      'archivedAt': archivedAt?.toIso8601String(),
      'archiveNotes': archiveNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BackupAnimal.fromJson(Map<String, dynamic> json) {
    return BackupAnimal(
      id: json['id'] as int,
      boxId: json['boxId'] as int?,
      status: json['status'] as String,
      commonName: json['commonName'] as String,
      latinName: json['latinName'] as String,
      sex: json['sex'] as String?,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate'] as String),
      birthDateAccuracy: json['birthDateAccuracy'] as String?,
      tempMin: (json['tempMin'] as num).toDouble(),
      tempMax: (json['tempMax'] as num).toDouble(),
      humidityMin: (json['humidityMin'] as num).toDouble(),
      humidityMax: (json['humidityMax'] as num).toDouble(),
      pictureMediaPath: json['pictureMediaPath'] as String?,
      notes: json['notes'] as String?,
      archiveReason: json['archiveReason'] as String?,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      archiveNotes: json['archiveNotes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class BackupFeedingEvent {
  final int id;
  final int animalId;
  final DateTime fedAt;
  final String? notes;

  const BackupFeedingEvent({
    required this.id,
    required this.animalId,
    required this.fedAt,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'animalId': animalId,
      'fedAt': fedAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory BackupFeedingEvent.fromJson(Map<String, dynamic> json) {
    return BackupFeedingEvent(
      id: json['id'] as int,
      animalId: json['animalId'] as int,
      fedAt: DateTime.parse(json['fedAt'] as String),
      notes: json['notes'] as String?,
    );
  }
}
