import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/enums/animal_archive_reason.dart';
import 'package:terramanager/core/database/enums/animal_status.dart';
import 'package:terramanager/core/database/enums/birth_date_accuracy.dart';
import 'package:terramanager/core/database/enums/sex.dart';
import 'package:terramanager/features/backup/domain/backup_enum_codec.dart';

void main() {
  group('AnimalStatus', () {
    test('encodes stable backup values', () {
      expect(BackupEnumCodec.encodeAnimalStatus(AnimalStatus.active), 'active');

      expect(
        BackupEnumCodec.encodeAnimalStatus(AnimalStatus.archived),
        'archived',
      );
    });

    test('decodes stable backup values', () {
      expect(BackupEnumCodec.decodeAnimalStatus('active'), AnimalStatus.active);

      expect(
        BackupEnumCodec.decodeAnimalStatus('archived'),
        AnimalStatus.archived,
      );
    });
  });

  group('AnimalArchiveReason', () {
    test('round trips all values', () {
      for (final value in AnimalArchiveReason.values) {
        final encoded = BackupEnumCodec.encodeArchiveReason(value);

        final decoded = BackupEnumCodec.decodeArchiveReason(encoded);

        expect(decoded, value);
      }
    });
  });

  group('BirthDateAccuracy', () {
    test('round trips all values', () {
      for (final value in BirthDateAccuracy.values) {
        final encoded = BackupEnumCodec.encodeBirthDateAccuracy(value);

        final decoded = BackupEnumCodec.decodeBirthDateAccuracy(encoded);

        expect(decoded, value);
      }
    });
  });

  group('Sex', () {
    test('round trips all values', () {
      for (final value in Sex.values) {
        final encoded = BackupEnumCodec.encodeSex(value);

        final decoded = BackupEnumCodec.decodeSex(encoded);

        expect(decoded, value);
      }
    });
  });

  test('unsupported backup enum value throws FormatException', () {
    expect(
      () => BackupEnumCodec.decodeAnimalStatus('future-status'),
      throwsFormatException,
    );

    expect(
      () => BackupEnumCodec.decodeArchiveReason('future-reason'),
      throwsFormatException,
    );

    expect(
      () => BackupEnumCodec.decodeBirthDateAccuracy('future-accuracy'),
      throwsFormatException,
    );

    expect(
      () => BackupEnumCodec.decodeSex('future-sex'),
      throwsFormatException,
    );
  });
}
