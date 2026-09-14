class AnimalEnvironmentalLimits {
  const AnimalEnvironmentalLimits._();

  static const double minimumTemperatureCelsius = 0;
  static const double maximumTemperatureCelsius = 60;
  static const double minimumHumidityPercent = 0;
  static const double maximumHumidityPercent = 100;

  static bool isWithinRange(double value, double minimum, double maximum) {
    return value.isFinite && value >= minimum && value <= maximum;
  }

  static void validate({
    required double temperatureMinimum,
    required double temperatureMaximum,
    required double humidityMinimum,
    required double humidityMaximum,
  }) {
    _requireWithinRange(
      fieldName: 'temperatureMinimum',
      value: temperatureMinimum,
      minimum: minimumTemperatureCelsius,
      maximum: maximumTemperatureCelsius,
    );
    _requireWithinRange(
      fieldName: 'temperatureMaximum',
      value: temperatureMaximum,
      minimum: minimumTemperatureCelsius,
      maximum: maximumTemperatureCelsius,
    );
    _requireWithinRange(
      fieldName: 'humidityMinimum',
      value: humidityMinimum,
      minimum: minimumHumidityPercent,
      maximum: maximumHumidityPercent,
    );
    _requireWithinRange(
      fieldName: 'humidityMaximum',
      value: humidityMaximum,
      minimum: minimumHumidityPercent,
      maximum: maximumHumidityPercent,
    );

    if (temperatureMinimum > temperatureMaximum) {
      throw ArgumentError(
        'temperatureMinimum must not be greater than temperatureMaximum',
      );
    }

    if (humidityMinimum > humidityMaximum) {
      throw ArgumentError(
        'humidityMinimum must not be greater than humidityMaximum',
      );
    }
  }

  static void _requireWithinRange({
    required String fieldName,
    required double value,
    required double minimum,
    required double maximum,
  }) {
    if (!isWithinRange(value, minimum, maximum)) {
      throw ArgumentError.value(
        value,
        fieldName,
        'must be between $minimum and $maximum',
      );
    }
  }
}
