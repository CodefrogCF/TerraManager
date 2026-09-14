import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/validation/animal_environmental_limits.dart';

void main() {
  test('accepts inclusive boundaries and decimal values', () {
    expect(
      () => AnimalEnvironmentalLimits.validate(
        temperatureMinimum: 0,
        temperatureMaximum: 60,
        humidityMinimum: 0.5,
        humidityMaximum: 99.5,
      ),
      returnsNormally,
    );
  });

  test('rejects out-of-range and non-finite values', () {
    for (final temperature in [-0.1, 60.1, double.nan, double.infinity]) {
      expect(
        () => AnimalEnvironmentalLimits.validate(
          temperatureMinimum: temperature,
          temperatureMaximum: 60,
          humidityMinimum: 40,
          humidityMaximum: 60,
        ),
        throwsArgumentError,
      );
    }

    for (final humidity in [-0.1, 100.1, double.nan, double.infinity]) {
      expect(
        () => AnimalEnvironmentalLimits.validate(
          temperatureMinimum: 20,
          temperatureMaximum: 30,
          humidityMinimum: humidity,
          humidityMaximum: 100,
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects reversed temperature and humidity ranges', () {
    expect(
      () => AnimalEnvironmentalLimits.validate(
        temperatureMinimum: 30,
        temperatureMaximum: 20,
        humidityMinimum: 40,
        humidityMaximum: 60,
      ),
      throwsArgumentError,
    );
    expect(
      () => AnimalEnvironmentalLimits.validate(
        temperatureMinimum: 20,
        temperatureMaximum: 30,
        humidityMinimum: 70,
        humidityMaximum: 60,
      ),
      throwsArgumentError,
    );
  });
}
