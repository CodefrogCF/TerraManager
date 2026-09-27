import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/date_only.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/feeding_repository.dart';
import 'package:terramanager/core/database/repositories/animal_weight_repository.dart';
import 'package:terramanager/core/database/repositories/shedding_repository.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_exception.dart';
import 'package:terramanager/features/backup/application/portable_backup_database_restorer.dart';
import 'package:terramanager/features/backup/application/portable_backup_exporter.dart';
import 'package:terramanager/features/backup/domain/backup_timestamps.dart';
import 'package:terramanager/shared_server/api_models.dart';
import 'package:terramanager/shared_server/shared_portable_backups.dart';

void main() {
  late AppDatabase source;
  late AppDatabase shared;
  late AppDatabase standalone;
  setUp(() {
    BackupTimestamps.zones;
    source = AppDatabase.test(NativeDatabase.memory());
    shared = AppDatabase.test(NativeDatabase.memory());
    standalone = AppDatabase.test(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await shared.close();
    await standalone.close();
  });

  for (final month in [1, 7]) {
    test(
      '19:00 Berlin in month $month survives export, Shared Care API and standalone roundtrip',
      () async {
        final time = tz.TZDateTime(
          tz.getLocation('Europe/Berlin'),
          2026,
          month,
          15,
          19,
        );
        final box = await BoxRepository(source)
            .createBoxWithGeneratedQrId(name: 'Box');
        final animal = await AnimalRepository(source).createAnimal(
          boxId: box,
          commonName: 'Animal',
          latinName: 'Species',
          birthDate: DateTime(2024, 1, 1),
          tempMin: 20,
          tempMax: 30,
          humidityMin: 40,
          humidityMax: 60,
          feedingReminderIntervalDays: 7,
          feedingReminderBaseline: time,
        );
        await FeedingRepository(source).addFeeding(animal, time);
        await AnimalWeightRepository(source)
            .add(animalId: animal, weightGrams: 12, measuredAt: time);
        await SheddingRepository(
          source,
        ).add(animalId: animal, shedAt: time, createdAt: time, updatedAt: time);
        final exported =
            await PortableBackupExporter(
              source,
              mediaReader: (_) async => throw StateError('No legacy media'),
            ).createBackup(
              appVersion: 'test',
              settings: SharedPortableBackups.collectionSettings,
            );
        final validated = SharedPortableBackups(shared)
            .validate(exported.bytes);
        expect(validated.hasLegacyTimestamps, false);
        expect(
          validated.data.feedingEvents.single.toJson()['fedAt'],
          time.toUtc().toIso8601String(),
        );
        expect(
          validated.data.animals.single.toJson()['birthDate'],
          '2024-01-01',
        );
        await SharedPortableBackups(shared).restore(validated);
        final fed = (await FeedingRepository(shared).getAllFeedings()).single;
        final apiDate = DateTime.parse(feedingJson(fed)['fedAt'] as String);
        expect(
          tz.TZDateTime.from(apiDate, tz.getLocation('Europe/Berlin')).hour,
          19,
        );
        expect(
          tz.TZDateTime.from(apiDate, tz.getLocation('America/New_York')).hour,
          13,
        );
        expect(apiDate.isAtSameMomentAs(time), true);
        expect(
          (await AnimalWeightRepository(shared).getHistory(animal))
              .single
              .measuredAt
              .isAtSameMomentAs(time),
          true,
        );
        expect(
          (await SheddingRepository(shared).getHistory(animal)).single.shedAt
              .isAtSameMomentAs(time),
          true,
        );
        final serverAnimal = (await AnimalRepository(shared)
            .getAnimalById(animal))!;
        expect(animalJson(serverAnimal)['birthDate'], '2024-01-01');
        expect(
          serverAnimal.feedingReminderBaseline!.isAtSameMomentAs(time),
          true,
        );
        final serverExport = await SharedPortableBackups(shared).export();
        await PortableBackupDatabaseRestorer(standalone)
            .restore(BackupValidationService().validate(serverExport.bytes));
        expect(
          (await FeedingRepository(
            standalone,
          ).getAllFeedings()).single.fedAt.isAtSameMomentAs(time),
          true,
        );
        expect(
          dateOnlyString(
            (await AnimalRepository(standalone).getAnimalById(animal))!
                .birthDate,
          ),
          '2024-01-01',
        );

        // Reproduce old v1/v2 wall-clock exports without explicit time zones.
        final archive = ZipDecoder().decodeBytes(exported.bytes);
        final dataFile = archive.findFile('data.json')!;
        final json = jsonDecode(
          utf8.decode(dataFile.content as List<int>),
        ) as Map<String, dynamic>;
        void legacy(Object? node) {
          if (node is Map) {
            for (final key in node.keys.toList()) {
              final value = node[key];
              if (value is String &&
                  key != 'birthDate' &&
                  RegExp(r'(At|Baseline)$').hasMatch(key as String)) {
                final local = tz.TZDateTime.from(
                  DateTime.parse(value),
                  tz.getLocation('Europe/Berlin'),
                );
                node[key] = DateTime.utc(
                  local.year,
                  local.month,
                  local.day,
                  local.hour,
                  local.minute,
                  local.second,
                ).toIso8601String().replaceAll('Z', '');
              } else {
                legacy(value);
              }
            }
          } else if (node is List) {
            for (final entry in node) {
              legacy(entry);
            }
          }
        }

        legacy(json);
        final oldArchive = Archive();
        for (final file in archive.files) {
          oldArchive.addFile(
            file.name == 'data.json'
                ? ArchiveFile.bytes(file.name, utf8.encode(jsonEncode(json)))
                : file,
          );
        }
        final oldBytes = Uint8List.fromList(ZipEncoder().encode(oldArchive));
        expect(
          () => SharedPortableBackups(shared).validate(oldBytes),
          throwsA(isA<BackupValidationException>()),
        );
        final fixed = SharedPortableBackups(shared)
            .validate(oldBytes, legacyTimeZone: 'Europe/Berlin');
        expect(fixed.hasLegacyTimestamps, true);
        expect(
          fixed.data.feedingEvents.single.fedAt.isAtSameMomentAs(time),
          true,
        );
        expect(
          fixed.data.animals.single.weightHistory.single.measuredAt
              .isAtSameMomentAs(time),
          true,
        );
        expect(
          fixed.data.animals.single.sheddingHistory.single.shedAt
              .isAtSameMomentAs(time),
          true,
        );
        expect(
          dateOnlyString(fixed.data.animals.single.birthDate),
          '2024-01-01',
        );
      },
    );
  }
  test('explicit offsets are preserved, ambiguous autumn chooses earlier and skipped spring rejects', () {
    final json = <String, dynamic>{
      'fedAt': '2026-10-25T02:30:00',
      'measuredAt': '2026-07-15T19:00:00+02:00',
      'birthDate': '2024-01-01',
    };
    BackupTimestamps.normalize(
      json,
      legacyTimeZone: 'Europe/Berlin',
      requireZone: true,
    );
    expect(json['fedAt'], '2026-10-25T00:30:00.000Z');
    expect(json['measuredAt'], '2026-07-15T19:00:00+02:00');
    expect(json['birthDate'], '2024-01-01');
    expect(
      () => BackupTimestamps.normalize(<String, dynamic>{
        'fedAt': '2026-03-29T02:30:00',
      }, legacyTimeZone: 'Europe/Berlin'),
      throwsFormatException,
    );
  });
  test(
    'legacy source timezone is independent of the importing client zone',
    () {
      final json = <String, dynamic>{
        'fedAt': '2026-07-15T19:00:00',
        'notes': '2026-07-15T19:00:00',
      };
      BackupTimestamps.normalize(
        json,
        legacyTimeZone: 'America/New_York',
        requireZone: true,
      );
      expect(json['fedAt'], '2026-07-15T23:00:00.000Z');
      expect(json['notes'], '2026-07-15T19:00:00');
      expect(
        tz.TZDateTime.from(
          DateTime.parse(json['fedAt']),
          tz.getLocation('Europe/Berlin'),
        ).day,
        16,
      );
    },
  );
  test('legacy date-only values preserve the written calendar day even with offsets', () {
    expect(
      dateOnlyString(parseDateOnly('2024-01-01T00:00:00+14:00')),
      '2024-01-01',
    );
    expect(
      dateOnlyString(parseDateOnly('2024-01-01T00:00:00-12:00')),
      '2024-01-01',
    );
    expect(() => parseDateOnly('2024-02-31'), throwsFormatException);
  });
}
