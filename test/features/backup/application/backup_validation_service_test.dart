import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/backup/application/backup_validation_exception.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/domain/backup_format.dart';

void main() {
  late BackupValidationService validator;

  setUp(() {
    validator = BackupValidationService();
  });

  Map<String, dynamic> manifestJson({
    int backupFormatVersion = BackupFormat.currentVersion,
  }) {
    return {
      'backupFormatVersion': backupFormatVersion,
      'appVersion': '0.6.0',
      'databaseSchemaVersion': 2,
      'createdAt': '2026-09-02T14:00:00.000Z',
    };
  }

  Map<String, dynamic> settingsJson({
    String themeMode = 'system',
    String accent = 'green',
  }) {
    return {'themeMode': themeMode, 'accent': accent};
  }

  Map<String, dynamic> activeAnimal({
    int id = 10,
    int? boxId = 1,
    String status = 'active',
    String? archiveReason,
    String? archivedAt,
    String? archiveNotes,
    String? pictureMediaPath,
  }) {
    return {
      'id': id,
      'boxId': boxId,
      'status': status,
      'commonName': 'Test Animal',
      'latinName': 'Test species',
      'sex': 'female',
      'birthDate': null,
      'birthDateAccuracy': null,
      'tempMin': 20.0,
      'tempMax': 25.0,
      'humidityMin': 40.0,
      'humidityMax': 60.0,
      'pictureMediaPath': pictureMediaPath,
      'notes': null,
      'archiveReason': archiveReason,
      'archivedAt': archivedAt,
      'archiveNotes': archiveNotes,
      'createdAt': '2026-08-01T10:00:00.000',
      'updatedAt': '2026-08-01T10:00:00.000',
    };
  }

  Map<String, dynamic> archivedAnimal({int id = 10}) {
    return {
      ...activeAnimal(id: id, boxId: null, status: 'archived'),
      'archiveReason': 'rehomed',
      'archivedAt': '2026-09-01T10:00:00.000',
      'archiveNotes': 'New keeper',
    };
  }

  Map<String, dynamic> dataJson({
    List<Map<String, dynamic>>? boxes,
    List<Map<String, dynamic>>? animals,
    List<Map<String, dynamic>>? feedingEvents,
  }) {
    return {
      'boxes':
          boxes ??
          [
            {
              'id': 1,
              'qrId': 'TM:BOX:11111111-1111-4111-8111-111111111111',
              'createdAt': '2026-08-01T10:00:00.000',
              'updatedAt': '2026-08-01T10:00:00.000',
            },
          ],
      'animals': animals ?? [activeAnimal()],
      'feedingEvents':
          feedingEvents ??
          [
            {
              'id': 100,
              'animalId': 10,
              'fedAt': '2026-09-01T18:30:00.000',
              'notes': 'Mouse',
            },
          ],
    };
  }

  Uint8List createArchive({
    Map<String, dynamic>? manifest,
    Map<String, dynamic>? data,
    Map<String, dynamic>? settings,
    Map<String, Uint8List> media = const {},
    bool includeManifest = true,
    bool includeData = true,
    bool includeSettings = true,
  }) {
    final archive = Archive();

    if (includeManifest) {
      archive.add(
        ArchiveFile.string(
          BackupFormat.manifestFileName,
          jsonEncode(manifest ?? manifestJson()),
        ),
      );
    }

    if (includeData) {
      archive.add(
        ArchiveFile.string(
          BackupFormat.dataFileName,
          jsonEncode(data ?? dataJson()),
        ),
      );
    }

    if (includeSettings) {
      archive.add(
        ArchiveFile.string(
          BackupFormat.settingsFileName,
          jsonEncode(settings ?? settingsJson()),
        ),
      );
    }

    for (final entry in media.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }

    return ZipEncoder().encodeBytes(archive);
  }

  test('accepts valid backup', () {
    final bytes = createArchive();

    final result = validator.validate(bytes);

    expect(result.manifest.backupFormatVersion, BackupFormat.currentVersion);

    expect(result.boxCount, 1);

    expect(result.animalCount, 1);

    expect(result.feedingEventCount, 1);

    expect(result.mediaFileCount, 0);
  });

  test('accepts valid archived animal', () {
    final bytes = createArchive(data: dataJson(animals: [archivedAnimal()]));

    final result = validator.validate(bytes);

    expect(result.data.animals.single.status, 'archived');

    expect(result.data.animals.single.boxId, isNull);
  });

  test('accepts legacy backup format version 1', () {
    final bytes = createArchive(manifest: manifestJson(backupFormatVersion: 1));

    final result = validator.validate(bytes);

    expect(result.manifest.backupFormatVersion, 1);

    expect(result.boxCount, 1);

    expect(result.data.boxes.single.widthCm, isNull);

    expect(result.data.boxes.single.pictureMediaPath, isNull);
  });

  test('rejects unsupported future backup format', () {
    final bytes = createArchive(
      manifest: manifestJson(
        backupFormatVersion: BackupFormat.currentVersion + 1,
      ),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.unsupportedBackupFormat,
        ),
      ),
    );
  });

  test('rejects missing manifest', () {
    final bytes = createArchive(includeManifest: false);

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.missingRequiredFile,
        ),
      ),
    );
  });

  test('rejects duplicate box ids', () {
    final box = {
      'id': 1,
      'qrId': 'TM:BOX:11111111-1111-4111-8111-111111111111',
      'createdAt': '2026-08-01T10:00:00.000',
      'updatedAt': '2026-08-01T10:00:00.000',
    };

    final secondBox = {
      ...box,
      'qrId': 'TM:BOX:22222222-2222-4222-8222-222222222222',
    };

    final bytes = createArchive(data: dataJson(boxes: [box, secondBox]));

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.duplicateRecordId,
        ),
      ),
    );
  });

  test('rejects duplicate qr ids', () {
    final bytes = createArchive(
      data: dataJson(
        boxes: [
          {
            'id': 1,
            'qrId': 'TM:BOX:11111111-1111-4111-8111-111111111111',
            'createdAt': '2026-08-01T10:00:00.000',
            'updatedAt': '2026-08-01T10:00:00.000',
          },
          {
            'id': 2,
            'qrId': 'TM:BOX:11111111-1111-4111-8111-111111111111',
            'createdAt': '2026-08-01T10:00:00.000',
            'updatedAt': '2026-08-01T10:00:00.000',
          },
        ],
      ),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.duplicateQrId,
        ),
      ),
    );
  });

  test('rejects invalid qr id', () {
    final bytes = createArchive(
      data: dataJson(
        boxes: [
          {
            'id': 1,
            'qrId': 'invalid',
            'createdAt': '2026-08-01T10:00:00.000',
            'updatedAt': '2026-08-01T10:00:00.000',
          },
        ],
      ),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidQrId,
        ),
      ),
    );
  });

  test('rejects active animal without box', () {
    final bytes = createArchive(
      data: dataJson(animals: [activeAnimal(boxId: null)]),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidLifecycle,
        ),
      ),
    );
  });

  test('rejects active animal referencing missing box', () {
    final bytes = createArchive(
      data: dataJson(animals: [activeAnimal(boxId: 999)]),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.brokenRelationship,
        ),
      ),
    );
  });

  test('rejects archived animal with box assignment', () {
    final animal = archivedAnimal();

    animal['boxId'] = 1;

    final bytes = createArchive(data: dataJson(animals: [animal]));

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidLifecycle,
        ),
      ),
    );
  });

  test('rejects feeding referencing missing animal', () {
    final bytes = createArchive(
      data: dataJson(
        feedingEvents: [
          {
            'id': 100,
            'animalId': 999,
            'fedAt': '2026-09-01T18:30:00.000',
            'notes': null,
          },
        ],
      ),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.brokenRelationship,
        ),
      ),
    );
  });

  test('rejects unsupported animal enum', () {
    final animal = activeAnimal();

    animal['sex'] = 'future-sex';

    final bytes = createArchive(data: dataJson(animals: [animal]));

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidEnum,
        ),
      ),
    );
  });

  test('rejects unsupported settings', () {
    final bytes = createArchive(
      settings: settingsJson(themeMode: 'future-theme'),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidSettings,
        ),
      ),
    );
  });

  test('accepts referenced media', () {
    const mediaPath = 'media/animals/10.jpg';

    final bytes = createArchive(
      data: dataJson(animals: [activeAnimal(pictureMediaPath: mediaPath)]),
      media: {
        mediaPath: Uint8List.fromList([1, 2, 3]),
      },
    );

    final result = validator.validate(bytes);

    expect(result.mediaFileCount, 1);

    expect(result.mediaFiles[mediaPath], Uint8List.fromList([1, 2, 3]));
  });

  test('rejects missing referenced media', () {
    final bytes = createArchive(
      data: dataJson(
        animals: [activeAnimal(pictureMediaPath: 'media/animals/10.jpg')],
      ),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.missingMedia,
        ),
      ),
    );
  });

  test('rejects unsafe media reference', () {
    final bytes = createArchive(
      data: dataJson(
        animals: [activeAnimal(pictureMediaPath: 'media/animals/../evil.jpg')],
      ),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidMediaReference,
        ),
      ),
    );
  });

  test('rejects invalid json', () {
    final archive = Archive();

    archive.add(
      ArchiveFile.string(
        BackupFormat.manifestFileName,
        '{ definitely not json',
      ),
    );

    archive.add(
      ArchiveFile.string(BackupFormat.dataFileName, jsonEncode(dataJson())),
    );

    archive.add(
      ArchiveFile.string(
        BackupFormat.settingsFileName,
        jsonEncode(settingsJson()),
      ),
    );

    final bytes = ZipEncoder().encodeBytes(archive);

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidJson,
        ),
      ),
    );
  });

  test('rejects archived animal without archive reason', () {
    final animal = archivedAnimal();

    animal['archiveReason'] = null;

    final bytes = createArchive(data: dataJson(animals: [animal]));

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidLifecycle,
        ),
      ),
    );
  });

  test('rejects active animal containing archive metadata', () {
    final bytes = createArchive(
      data: dataJson(
        animals: [
          activeAnimal(
            archiveReason: 'sold',
            archivedAt: '2026-09-01T10:00:00.000',
          ),
        ],
      ),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidLifecycle,
        ),
      ),
    );
  });

  test('allows custom qr validator injection', () {
    final customValidator = BackupValidationService(
      qrIdValidator: (_) => false,
    );

    final bytes = createArchive();

    expect(
      () => customValidator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidQrId,
        ),
      ),
    );
  });

  test('accepts box dimensions and referenced media', () {
    const mediaPath = 'media/boxes/1.png';

    final bytes = createArchive(
      data: dataJson(
        boxes: [
          {
            'id': 1,
            'qrId': 'TM:BOX:11111111-1111-4111-8111-111111111111',
            'widthCm': 60.0,
            'heightCm': 40.0,
            'depthCm': 45.0,
            'pictureMediaPath': mediaPath,
            'createdAt': '2026-08-01T10:00:00.000',
            'updatedAt': '2026-08-01T10:00:00.000',
          },
        ],
      ),
      media: {
        mediaPath: Uint8List.fromList([1, 2, 3]),
      },
    );

    final result = validator.validate(bytes);

    final box = result.data.boxes.single;

    expect(box.widthCm, 60);
    expect(box.heightCm, 40);
    expect(box.depthCm, 45);

    expect(box.pictureMediaPath, mediaPath);

    expect(result.mediaFileCount, 1);

    expect(result.mediaFiles[mediaPath], Uint8List.fromList([1, 2, 3]));
  });

  test('rejects missing referenced box media', () {
    final bytes = createArchive(
      data: dataJson(
        boxes: [
          {
            'id': 1,
            'qrId': 'TM:BOX:11111111-1111-4111-8111-111111111111',
            'widthCm': null,
            'heightCm': null,
            'depthCm': null,
            'pictureMediaPath': 'media/boxes/1.jpg',
            'createdAt': '2026-08-01T10:00:00.000',
            'updatedAt': '2026-08-01T10:00:00.000',
          },
        ],
      ),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.missingMedia,
        ),
      ),
    );
  });

  test('rejects invalid box media reference', () {
    const mediaPath = 'media/animals/1.jpg';

    final bytes = createArchive(
      data: dataJson(
        boxes: [
          {
            'id': 1,
            'qrId': 'TM:BOX:11111111-1111-4111-8111-111111111111',
            'widthCm': null,
            'heightCm': null,
            'depthCm': null,
            'pictureMediaPath': mediaPath,
            'createdAt': '2026-08-01T10:00:00.000',
            'updatedAt': '2026-08-01T10:00:00.000',
          },
        ],
      ),
      media: {
        mediaPath: Uint8List.fromList([1]),
      },
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidMediaReference,
        ),
      ),
    );
  });

  test('rejects empty referenced box media', () {
    const mediaPath = 'media/boxes/1.jpg';

    final bytes = createArchive(
      data: dataJson(
        boxes: [
          {
            'id': 1,
            'qrId': 'TM:BOX:11111111-1111-4111-8111-111111111111',
            'pictureMediaPath': mediaPath,
            'createdAt': '2026-08-01T10:00:00.000',
            'updatedAt': '2026-08-01T10:00:00.000',
          },
        ],
      ),
      media: {mediaPath: Uint8List(0)},
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.emptyMedia,
        ),
      ),
    );
  });

  test('rejects non-positive box dimension', () {
    final bytes = createArchive(
      data: dataJson(
        boxes: [
          {
            'id': 1,
            'qrId': 'TM:BOX:11111111-1111-4111-8111-111111111111',
            'widthCm': 0.0,
            'heightCm': 40.0,
            'depthCm': 40.0,
            'pictureMediaPath': null,
            'createdAt': '2026-08-01T10:00:00.000',
            'updatedAt': '2026-08-01T10:00:00.000',
          },
        ],
      ),
    );

    expect(
      () => validator.validate(bytes),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.code,
          'code',
          BackupValidationErrorCode.invalidData,
        ),
      ),
    );
  });
}
