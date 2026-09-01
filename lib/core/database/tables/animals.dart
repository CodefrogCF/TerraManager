import 'package:drift/drift.dart';

import '../converters/animal_archive_reason_converter.dart';
import '../converters/animal_status_converter.dart';
import '../converters/birth_date_accuracy_converter.dart';
import '../converters/sex_converter.dart';
import 'boxes.dart';

@DataClassName('Animal')
class Animals extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get boxId => integer()
      .references(Boxes, #id)
      .nullable()();

  TextColumn get status => text()
      .withDefault(
        const Constant('active'),
      )
      .map(
        const AnimalStatusConverter(),
      )();

  TextColumn get commonName => text()();

  TextColumn get latinName => text()();

  TextColumn get sex => text()
      .map(
        const SexConverter(),
      )
      .nullable()();

  DateTimeColumn get birthDate =>
      dateTime().nullable()();

  TextColumn get birthDateAccuracy => text()
      .map(
        const BirthDateAccuracyConverter(),
      )
      .nullable()();

  RealColumn get tempMin => real()();

  RealColumn get tempMax => real()();

  RealColumn get humidityMin => real()();

  RealColumn get humidityMax => real()();

  TextColumn get picturePath =>
      text().nullable()();

  TextColumn get notes =>
      text().nullable()();

  TextColumn get archiveReason => text()
      .map(
        const AnimalArchiveReasonConverter(),
      )
      .nullable()();

  DateTimeColumn get archivedAt =>
      dateTime().nullable()();

  TextColumn get archiveNotes =>
      text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(
        currentDateAndTime,
      )();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(
        currentDateAndTime,
      )();
}