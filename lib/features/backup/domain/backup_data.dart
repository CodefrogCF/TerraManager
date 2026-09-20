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
  final String status;
  final String? archiveReason;
  final DateTime? archivedAt;
  final String? archiveNotes;

  final String? name;

  final double? widthCm;
  final double? heightCm;
  final double? depthCm;

  final String? temperatureZones;
  final String? notes;

  final String? pictureMediaPath;
  final List<BackupPicture> pictures;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BackupBox({
    required this.id,
    required this.qrId,
    this.status = 'active',
    this.archiveReason,
    this.archivedAt,
    this.archiveNotes,
    this.name,
    this.widthCm,
    this.heightCm,
    this.depthCm,
    this.temperatureZones,
    this.notes,
    this.pictureMediaPath,
    this.pictures = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'qrId': qrId,
      'status': status,
      'archiveReason': archiveReason,
      'archivedAt': archivedAt?.toIso8601String(),
      'archiveNotes': archiveNotes,
      'name': name,
      'widthCm': widthCm,
      'heightCm': heightCm,
      'depthCm': depthCm,
      'temperatureZones': temperatureZones,
      'notes': notes,
      'pictureMediaPath': pictureMediaPath,
      'pictures': pictures.map((picture) => picture.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BackupBox.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final pictureMediaPath = json['pictureMediaPath'] as String?;
    return BackupBox(
      id: json['id'] as int,
      qrId: json['qrId'] as String,
      // Only absent status is legacy data; an explicit null is invalid.
      status: json.containsKey('status') ? json['status'] as String : 'active',
      archiveReason: json['archiveReason'] as String?,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      archiveNotes: json['archiveNotes'] as String?,
      name: json['name'] as String?,
      widthCm: (json['widthCm'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      depthCm: (json['depthCm'] as num?)?.toDouble(),
      temperatureZones: json['temperatureZones'] as String?,
      notes: json['notes'] as String?,
      pictureMediaPath: pictureMediaPath,
      pictures: _picturesFromJson(
        json,
        fallbackMediaPath: pictureMediaPath,
        fallbackCapturedAt: createdAt,
      ),
      createdAt: createdAt,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class BackupWeightEntry {
  final int id;
  final double weightGrams;
  final DateTime measuredAt;

  const BackupWeightEntry({
    required this.id,
    required this.weightGrams,
    required this.measuredAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'weightGrams': weightGrams,
    'measuredAt': measuredAt.toIso8601String(),
  };

  factory BackupWeightEntry.fromJson(Map<String, dynamic> json) {
    return BackupWeightEntry(
      id: json['id'] as int,
      weightGrams: (json['weightGrams'] as num).toDouble(),
      measuredAt: DateTime.parse(json['measuredAt'] as String),
    );
  }
}

class BackupSheddingEvent {
  final int id;
  final DateTime shedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BackupSheddingEvent({
    required this.id,
    required this.shedAt,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shedAt': shedAt.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BackupSheddingEvent.fromJson(Map<String, dynamic> json) {
    return BackupSheddingEvent(
      id: json['id'] as int,
      shedAt: DateTime.parse(json['shedAt'] as String),
      notes: json['notes'] as String?,
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

  final String category;
  final String? subcategory;

  final String? sex;

  final DateTime? birthDate;
  final String? birthDateAccuracy;

  final double tempMin;
  final double tempMax;
  final double? nighttimeTemperature;
  final double? nighttimeTemperatureMin;
  final double? nighttimeTemperatureMax;

  final double humidityMin;
  final double humidityMax;

  final String? originHabitat;
  final String? weight;
  final List<BackupWeightEntry> weightHistory;
  final String? sheddingNotes;
  final List<BackupSheddingEvent> sheddingHistory;
  final String? restOrDormancyPeriods;
  final String? temperatureZones;

  final String? pictureMediaPath;
  final List<BackupPicture> pictures;
  final String? notes;

  final String? archiveReason;
  final DateTime? archivedAt;
  final String? archiveNotes;

  final int? feedingReminderIntervalDays;
  final DateTime? feedingReminderBaseline;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BackupAnimal({
    required this.id,
    required this.boxId,
    required this.status,
    required this.commonName,
    required this.latinName,
    this.category = 'other',
    this.subcategory,
    required this.sex,
    required this.birthDate,
    required this.birthDateAccuracy,
    required this.tempMin,
    required this.tempMax,
    this.nighttimeTemperature,
    this.nighttimeTemperatureMin,
    this.nighttimeTemperatureMax,
    required this.humidityMin,
    required this.humidityMax,
    this.originHabitat,
    this.weight,
    this.weightHistory = const [],
    this.sheddingNotes,
    this.sheddingHistory = const [],
    this.restOrDormancyPeriods,
    this.temperatureZones,
    required this.pictureMediaPath,
    this.pictures = const [],
    required this.notes,
    required this.archiveReason,
    required this.archivedAt,
    required this.archiveNotes,
    this.feedingReminderIntervalDays,
    this.feedingReminderBaseline,
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
      'category': category,
      'subcategory': subcategory,
      'sex': sex,
      'birthDate': birthDate?.toIso8601String(),
      'birthDateAccuracy': birthDateAccuracy,
      'tempMin': tempMin,
      'tempMax': tempMax,
      'nighttimeTemperature': nighttimeTemperature,
      'nighttimeTemperatureMin': nighttimeTemperatureMin,
      'nighttimeTemperatureMax': nighttimeTemperatureMax,
      'humidityMin': humidityMin,
      'humidityMax': humidityMax,
      'originHabitat': originHabitat,
      'weight': weight,
      'weightHistory': weightHistory.map((entry) => entry.toJson()).toList(),
      'sheddingNotes': sheddingNotes,
      'sheddingHistory': sheddingHistory
          .map((entry) => entry.toJson())
          .toList(),
      'restOrDormancyPeriods': restOrDormancyPeriods,
      'temperatureZones': temperatureZones,
      'pictureMediaPath': pictureMediaPath,
      'pictures': pictures.map((picture) => picture.toJson()).toList(),
      'notes': notes,
      'archiveReason': archiveReason,
      'archivedAt': archivedAt?.toIso8601String(),
      'archiveNotes': archiveNotes,
      'feedingReminderIntervalDays': feedingReminderIntervalDays,
      'feedingReminderBaseline': feedingReminderBaseline?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BackupAnimal.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final pictureMediaPath = json['pictureMediaPath'] as String?;
    return BackupAnimal(
      id: json['id'] as int,
      boxId: json['boxId'] as int?,
      status: json['status'] as String,
      commonName: json['commonName'] as String,
      latinName: json['latinName'] as String,
      category: json.containsKey('category')
          ? json['category'] as String
          : 'other',
      subcategory: json['subcategory'] as String?,
      sex: json['sex'] as String?,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate'] as String),
      birthDateAccuracy: json['birthDateAccuracy'] as String?,
      tempMin: (json['tempMin'] as num).toDouble(),
      tempMax: (json['tempMax'] as num).toDouble(),
      nighttimeTemperature: (json['nighttimeTemperature'] as num?)?.toDouble(),
      nighttimeTemperatureMin: (json['nighttimeTemperatureMin'] as num?)
          ?.toDouble(),
      nighttimeTemperatureMax: (json['nighttimeTemperatureMax'] as num?)
          ?.toDouble(),
      humidityMin: (json['humidityMin'] as num).toDouble(),
      humidityMax: (json['humidityMax'] as num).toDouble(),
      originHabitat: json['originHabitat'] as String?,
      weight: json['weight'] as String?,
      weightHistory: (json['weightHistory'] as List<dynamic>? ?? const [])
          .map(
            (entry) => BackupWeightEntry.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
      sheddingNotes: json['sheddingNotes'] as String?,
      sheddingHistory: (json['sheddingHistory'] as List<dynamic>? ?? const [])
          .map(
            (entry) => BackupSheddingEvent.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
      restOrDormancyPeriods: json['restOrDormancyPeriods'] as String?,
      temperatureZones: json['temperatureZones'] as String?,
      pictureMediaPath: pictureMediaPath,
      pictures: _picturesFromJson(
        json,
        fallbackMediaPath: pictureMediaPath,
        fallbackCapturedAt: createdAt,
      ),
      notes: json['notes'] as String?,
      archiveReason: json['archiveReason'] as String?,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      archiveNotes: json['archiveNotes'] as String?,
      feedingReminderIntervalDays: json['feedingReminderIntervalDays'] as int?,
      feedingReminderBaseline: json['feedingReminderBaseline'] == null
          ? null
          : DateTime.parse(json['feedingReminderBaseline'] as String),
      createdAt: createdAt,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class BackupPicture {
  const BackupPicture({required this.mediaPath, required this.capturedAt});

  final String mediaPath;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() {
    return {'mediaPath': mediaPath, 'capturedAt': capturedAt.toIso8601String()};
  }

  factory BackupPicture.fromJson(Map<String, dynamic> json) {
    return BackupPicture(
      mediaPath: json['mediaPath'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
    );
  }
}

List<BackupPicture> _picturesFromJson(
  Map<String, dynamic> json, {
  required String? fallbackMediaPath,
  required DateTime fallbackCapturedAt,
}) {
  if (json.containsKey('pictures')) {
    return (json['pictures'] as List<dynamic>)
        .map((item) => BackupPicture.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
  if (fallbackMediaPath == null) {
    return const [];
  }
  return [
    BackupPicture(mediaPath: fallbackMediaPath, capturedAt: fallbackCapturedAt),
  ];
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
