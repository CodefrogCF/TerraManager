import 'package:terramanager/core/database/enums/animal_category.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

class AnimalCommand {
  final int boxId;
  final String commonName;
  final String latinName;
  final AnimalCategory category;
  final AnimalSubcategory? subcategory;
  final Sex? sex;
  final DateTime? birthDate;
  final BirthDateAccuracy? birthDateAccuracy;
  final double tempMin;
  final double tempMax;
  final double? nighttimeTemperatureMin;
  final double? nighttimeTemperatureMax;
  final double humidityMin;
  final double humidityMax;
  final String? originHabitat;
  final String? restOrDormancyPeriods;
  final String? notes;
  final int? pictureMediaId;
  final int? feedingReminderIntervalDays;
  final DateTime? feedingReminderBaseline;
  final int? feedingReminderWeekdays;
  final int? feedingReminderMinuteOfDay;
  final String? feedingReminderTimeZone;
  final double? weightGrams;
  final DateTime? weightMeasuredAt;
  final bool showWeightOnDetail;
  final bool showSheddingOnDetail;

  const AnimalCommand({
    required this.boxId,
    required this.commonName,
    required this.latinName,
    required this.category,
    required this.subcategory,
    required this.sex,
    required this.birthDate,
    required this.birthDateAccuracy,
    required this.tempMin,
    required this.tempMax,
    required this.nighttimeTemperatureMin,
    required this.nighttimeTemperatureMax,
    required this.humidityMin,
    required this.humidityMax,
    required this.originHabitat,
    required this.restOrDormancyPeriods,
    required this.notes,
    required this.pictureMediaId,
    required this.feedingReminderIntervalDays,
    required this.feedingReminderBaseline,
    required this.feedingReminderWeekdays,
    required this.feedingReminderMinuteOfDay,
    required this.feedingReminderTimeZone,
    required this.weightGrams,
    required this.weightMeasuredAt,
    required this.showWeightOnDetail,
    required this.showSheddingOnDetail,
  });

  factory AnimalCommand.fromInput(ApiInput input, {bool creating = false}) {
    input.allow(const {
      'boxId',
      'commonName',
      'latinName',
      'category',
      'subcategory',
      'sex',
      'birthDate',
      'birthDateAccuracy',
      'tempMin',
      'tempMax',
      'nighttimeTemperatureMin',
      'nighttimeTemperatureMax',
      'humidityMin',
      'humidityMax',
      'originHabitat',
      'restOrDormancyPeriods',
      'notes',
      'pictureMediaId',
      'feedingReminderIntervalDays',
      'feedingReminderBaseline',
      'feedingReminderWeekdays',
      'feedingReminderMinuteOfDay',
      'feedingReminderTimeZone',
      'weightGrams',
      'weightMeasuredAt',
      'showWeightOnDetail',
      'showSheddingOnDetail',
    });
    final category = creating && !input.values.containsKey('category')
        ? AnimalCategory.other
        : input.enumerated('category', AnimalCategory.values);
    final weightGrams = input.nullableNumber('weightGrams');
    if (weightGrams != null && weightGrams <= 0) {
      throw const ApiProblem(
        400,
        'invalid_data',
        'weightGrams must be positive.',
      );
    }
    if (input.values.containsKey('weightMeasuredAt') && weightGrams == null) {
      throw const ApiProblem(
        400,
        'invalid_data',
        'weightMeasuredAt requires weightGrams.',
      );
    }
    return AnimalCommand(
      boxId: input.integer('boxId'),
      commonName: input.string('commonName'),
      latinName: input.string('latinName'),
      category: category,
      subcategory: input.nullableEnum('subcategory', AnimalSubcategory.values),
      sex: input.nullableEnum('sex', Sex.values),
      birthDate: input.nullableDateOnly('birthDate'),
      birthDateAccuracy: input.nullableEnum(
        'birthDateAccuracy',
        BirthDateAccuracy.values,
      ),
      tempMin: input.number('tempMin'),
      tempMax: input.number('tempMax'),
      nighttimeTemperatureMin: input.nullableNumber('nighttimeTemperatureMin'),
      nighttimeTemperatureMax: input.nullableNumber('nighttimeTemperatureMax'),
      humidityMin: input.number('humidityMin'),
      humidityMax: input.number('humidityMax'),
      originHabitat: input.nullableString('originHabitat'),
      restOrDormancyPeriods: input.nullableString('restOrDormancyPeriods'),
      notes: input.nullableString('notes'),
      pictureMediaId: input.nullableInteger('pictureMediaId'),
      feedingReminderIntervalDays: input.nullableInteger(
        'feedingReminderIntervalDays',
      ),
      feedingReminderBaseline: input.nullableDateTime(
        'feedingReminderBaseline',
      ),
      feedingReminderWeekdays: input.nullableInteger('feedingReminderWeekdays'),
      feedingReminderMinuteOfDay: input.nullableInteger(
        'feedingReminderMinuteOfDay',
      ),
      feedingReminderTimeZone: input.nullableString('feedingReminderTimeZone'),
      weightGrams: weightGrams,
      weightMeasuredAt: input.nullableDateTime('weightMeasuredAt'),
      showWeightOnDetail: input.boolean(
        'showWeightOnDetail',
        fallback: creating ? true : null,
      ),
      showSheddingOnDetail: input.boolean(
        'showSheddingOnDetail',
        fallback: creating ? true : null,
      ),
    );
  }
}
