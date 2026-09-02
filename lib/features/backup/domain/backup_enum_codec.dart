import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/sex.dart';

class BackupEnumCodec {
  BackupEnumCodec._();

  static String encodeAnimalStatus(AnimalStatus value) {
    return switch (value) {
      AnimalStatus.active => 'active',
      AnimalStatus.archived => 'archived',
    };
  }

  static AnimalStatus decodeAnimalStatus(String value) {
    return switch (value) {
      'active' => AnimalStatus.active,
      'archived' => AnimalStatus.archived,
      _ => throw FormatException(
        'Unsupported AnimalStatus backup value: $value',
      ),
    };
  }

  static String encodeArchiveReason(AnimalArchiveReason value) {
    return switch (value) {
      AnimalArchiveReason.sold => 'sold',
      AnimalArchiveReason.traded => 'traded',
      AnimalArchiveReason.deceased => 'deceased',
      AnimalArchiveReason.rehomed => 'rehomed',
      AnimalArchiveReason.other => 'other',
    };
  }

  static AnimalArchiveReason decodeArchiveReason(String value) {
    return switch (value) {
      'sold' => AnimalArchiveReason.sold,
      'traded' => AnimalArchiveReason.traded,
      'deceased' => AnimalArchiveReason.deceased,
      'rehomed' => AnimalArchiveReason.rehomed,
      'other' => AnimalArchiveReason.other,
      _ => throw FormatException(
        'Unsupported AnimalArchiveReason backup value: $value',
      ),
    };
  }

  static String encodeBirthDateAccuracy(BirthDateAccuracy value) {
    return switch (value) {
      BirthDateAccuracy.exact => 'exact',
      BirthDateAccuracy.monthKnown => 'monthKnown',
      BirthDateAccuracy.yearKnown => 'yearKnown',
    };
  }

  static BirthDateAccuracy decodeBirthDateAccuracy(String value) {
    return switch (value) {
      'exact' => BirthDateAccuracy.exact,
      'monthKnown' => BirthDateAccuracy.monthKnown,
      'yearKnown' => BirthDateAccuracy.yearKnown,
      _ => throw FormatException(
        'Unsupported BirthDateAccuracy backup value: $value',
      ),
    };
  }

  static String encodeSex(Sex value) {
    return switch (value) {
      Sex.male => 'male',
      Sex.female => 'female',
      Sex.unknown => 'unknown',
    };
  }

  static Sex decodeSex(String value) {
    return switch (value) {
      'male' => Sex.male,
      'female' => Sex.female,
      'unknown' => Sex.unknown,
      _ => throw FormatException('Unsupported Sex backup value: $value'),
    };
  }
}
