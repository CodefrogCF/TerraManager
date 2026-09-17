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
    double? nighttimeTemperature,
    double? nighttimeTemperatureMinimum,
    double? nighttimeTemperatureMaximum,
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

    final effectiveNightMinimum =
        nighttimeTemperatureMinimum ?? nighttimeTemperature;
    final effectiveNightMaximum =
        nighttimeTemperatureMaximum ?? nighttimeTemperature;
    if (effectiveNightMinimum != null) {
      _requireWithinRange(
        fieldName: 'nighttimeTemperatureMinimum',
        value: effectiveNightMinimum,
        minimum: minimumTemperatureCelsius,
        maximum: maximumTemperatureCelsius,
      );
    }
    if (effectiveNightMaximum != null) {
      _requireWithinRange(
        fieldName: 'nighttimeTemperatureMaximum',
        value: effectiveNightMaximum,
        minimum: minimumTemperatureCelsius,
        maximum: maximumTemperatureCelsius,
      );
    }

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

    _requireOrdered(
      minimumName: 'temperatureMinimum',
      minimum: temperatureMinimum,
      maximumName: 'temperatureMaximum',
      maximum: temperatureMaximum,
    );
    if (effectiveNightMinimum != null && effectiveNightMaximum != null) {
      _requireOrdered(
        minimumName: 'nighttimeTemperatureMinimum',
        minimum: effectiveNightMinimum,
        maximumName: 'nighttimeTemperatureMaximum',
        maximum: effectiveNightMaximum,
      );
    }
    _requireOrdered(
      minimumName: 'humidityMinimum',
      minimum: humidityMinimum,
      maximumName: 'humidityMaximum',
      maximum: humidityMaximum,
    );
  }

  static void _requireOrdered({
    required String minimumName,
    required double minimum,
    required String maximumName,
    required double maximum,
  }) {
    if (minimum > maximum) {
      throw ArgumentError('$minimumName must not be greater than $maximumName');
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
