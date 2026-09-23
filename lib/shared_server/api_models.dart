import '../core/database/app_database.dart';
import '../core/database/repositories/picture_gallery_repository.dart';

String? _date(DateTime? value) => value?.toUtc().toIso8601String();

Map<String, dynamic> boxJson(Box box) => {
  'id': box.id,
  'qrId': box.qrId,
  'status': box.status.name,
  'archiveReason': box.archiveReason?.name,
  'archivedAt': _date(box.archivedAt),
  'archiveNotes': box.archiveNotes,
  'name': box.name,
  'widthCm': box.widthCm,
  'heightCm': box.heightCm,
  'depthCm': box.depthCm,
  'temperatureZones': box.temperatureZones,
  'notes': box.notes,
  'pictureMediaId': box.pictureMediaId,
  'createdAt': _date(box.createdAt),
  'updatedAt': _date(box.updatedAt),
};

Map<String, dynamic> animalJson(Animal animal) => {
  'id': animal.id,
  'boxId': animal.boxId,
  'status': animal.status.name,
  'commonName': animal.commonName,
  'latinName': animal.latinName,
  'category': animal.category.name,
  'subcategory': animal.subcategory?.name,
  'sex': animal.sex?.name,
  'birthDate': _date(animal.birthDate),
  'birthDateAccuracy': animal.birthDateAccuracy?.name,
  'tempMin': animal.tempMin,
  'tempMax': animal.tempMax,
  'nighttimeTemperature': animal.nighttimeTemperature,
  'nighttimeTemperatureMin': animal.nighttimeTemperatureMin,
  'nighttimeTemperatureMax': animal.nighttimeTemperatureMax,
  'humidityMin': animal.humidityMin,
  'humidityMax': animal.humidityMax,
  'originHabitat': animal.originHabitat,
  'weight': animal.weight,
  'sheddingNotes': animal.sheddingNotes,
  'restOrDormancyPeriods': animal.restOrDormancyPeriods,
  'temperatureZones': animal.temperatureZones,
  'notes': animal.notes,
  'picturePath': animal.picturePath,
  'pictureMediaId': animal.pictureMediaId,
  'archiveReason': animal.archiveReason?.name,
  'archivedAt': _date(animal.archivedAt),
  'archiveNotes': animal.archiveNotes,
  'feedingReminderIntervalDays': animal.feedingReminderIntervalDays,
  'feedingReminderBaseline': _date(animal.feedingReminderBaseline),
  'showWeightOnDetail': animal.showWeightOnDetail,
  'showSheddingOnDetail': animal.showSheddingOnDetail,
  'createdAt': _date(animal.createdAt),
  'updatedAt': _date(animal.updatedAt),
};

Map<String, dynamic> feedingJson(FeedingEvent event) => {
  'id': event.id,
  'animalId': event.animalId,
  'fedAt': _date(event.fedAt),
  'notes': event.notes,
};

Map<String, dynamic> weightJson(AnimalWeightEntry entry) => {
  'id': entry.id,
  'animalId': entry.animalId,
  'weightGrams': entry.weightGrams,
  'measuredAt': _date(entry.measuredAt),
};

Map<String, dynamic> sheddingJson(SheddingEvent event) => {
  'id': event.id,
  'animalId': event.animalId,
  'shedAt': _date(event.shedAt),
  'notes': event.notes,
  'createdAt': _date(event.createdAt),
  'updatedAt': _date(event.updatedAt),
};

Map<String, dynamic> pictureJson(PictureGalleryEntry entry) => {
  'associationId': entry.associationId,
  'mediaId': entry.media.id,
  'fileName': entry.media.fileName,
  'mimeType': entry.media.mimeType,
  'capturedAt': _date(entry.capturedAt),
  'sortOrder': entry.sortOrder,
  'isPrimary': entry.isPrimary,
};
