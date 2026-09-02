import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/backup/application/backup_export_result.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/infrastructure/backup_file_service.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';

class FakeBackupFileGateway implements BackupFileGateway {
  PickedBackupFile? pickedFile;

  final List<BackupExportResult> savedBackups = [];

  @override
  Future<PickedBackupFile?> pickBackup() async {
    return pickedFile;
  }

  @override
  Future<String> saveBackup(BackupExportResult backup) async {
    savedBackups.add(backup);

    return backup.fileName;
  }
}

void main() {
  late AppDatabase database;
  late AppDatabase sourceDatabase;

  late AppSettingsController settingsController;

  late FakeBackupFileGateway fileGateway;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'light',
      'accent': 'red',
    });

    database = AppDatabase.test(NativeDatabase.memory());

    sourceDatabase = AppDatabase.test(NativeDatabase.memory());

    settingsController = AppSettingsController();

    await settingsController.load();

    fileGateway = FakeBackupFileGateway();
  });

  tearDown(() async {
    settingsController.dispose();

    await database.close();
    await sourceDatabase.close();
  });

  Widget buildApp({VoidCallback? onRestoreCompleted}) {
    return AppSettingsScope(
      controller: settingsController,
      child: MaterialApp(
        home: SettingsPage(
          database: database,
          backupFileGateway: fileGateway,
          appVersionLoader: () async => '0.6.0',
          onRestoreCompleted: onRestoreCompleted,
        ),
      ),
    );
  }

  Future<void> scrollToKey(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration step = const Duration(milliseconds: 100),
    int maxPumps = 100,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      await tester.pump(step);

      if (condition()) {
        return;
      }
    }

    fail(
      'Condition was not reached after '
      '${step.inMilliseconds * maxPumps} ms.',
    );
  }

  testWidgets('creates and saves backup', (tester) async {
    await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
          ),
        );

    await tester.pumpWidget(buildApp());

    await scrollToKey(tester, const Key('create-backup-button'));

    await tester.tap(find.byKey(const Key('create-backup-button')));

    await pumpUntil(tester, () => fileGateway.savedBackups.length == 1);

    await tester.pump();

    expect(fileGateway.savedBackups.length, 1);

    expect(fileGateway.savedBackups.single.data.boxes.length, 1);

    expect(find.text('Backup created successfully.'), findsOneWidget);
    expect(find.byKey(const Key('backup-progress')), findsNothing);
  });

  testWidgets('validates confirms and restores backup without media', (
    tester,
  ) async {
    await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
          ),
        );

    await sourceDatabase
        .into(sourceDatabase.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:22222222-2222-4222-8222-222222222222',
            createdAt: drift.Value(DateTime(2026, 9, 1)),
            updatedAt: drift.Value(DateTime(2026, 9, 1)),
          ),
        );

    final sourceBackup = await BackupExportService(sourceDatabase).createBackup(
      appVersion: '0.6.0',
      themeMode: ThemeMode.dark,
      accent: settingsController.accent,
      createdAt: DateTime.utc(2026, 9, 2, 15),
    );

    fileGateway.pickedFile = PickedBackupFile(
      name: sourceBackup.fileName,
      bytes: sourceBackup.bytes,
    );

    var restoreCompleted = false;

    await tester.pumpWidget(
      buildApp(
        onRestoreCompleted: () {
          restoreCompleted = true;
        },
      ),
    );

    await scrollToKey(tester, const Key('restore-backup-button'));

    await tester.tap(find.byKey(const Key('restore-backup-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backup-info-dialog')), findsOneWidget);

    expect(find.text('Boxes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('backup-info-continue-button')));

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('restore-confirmation-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('restore-confirm-button')));

    await tester.pumpAndSettle();

    final boxes = await database.select(database.boxes).get();

    expect(boxes.length, 1);

    expect(boxes.single.qrId, 'TM:BOX:22222222-2222-4222-8222-222222222222');

    expect(restoreCompleted, isTrue);

    // The restore creates and saves a safety
    // backup before replacing data.
    expect(fileGateway.savedBackups.length, 1);

    expect(
      fileGateway.savedBackups.single.data.boxes.single.qrId,
      'TM:BOX:11111111-1111-4111-8111-111111111111',
    );

    expect(find.text('Backup restored successfully.'), findsOneWidget);
  });

  testWidgets(
    'does not start restore with media when media storage is unavailable',
    (tester) async {
      final boxId = await sourceDatabase
          .into(sourceDatabase.boxes)
          .insert(
            BoxesCompanion.insert(
              qrId: 'TM:BOX:33333333-3333-4333-8333-333333333333',
            ),
          );

      await sourceDatabase
          .into(sourceDatabase.animals)
          .insert(
            AnimalsCompanion.insert(
              boxId: drift.Value(boxId),
              commonName: 'Picture Animal',
              latinName: 'Test species',
              tempMin: 20,
              tempMax: 25,
              humidityMin: 40,
              humidityMax: 60,
              picturePath: const drift.Value('test/image.jpg'),
            ),
          );

      final sourceBackup =
          await BackupExportService(
            sourceDatabase,
            mediaReader: (_) async {
              return Uint8List.fromList([1, 2, 3]);
            },
          ).createBackup(
            appVersion: '0.6.0',
            themeMode: ThemeMode.system,
            accent: settingsController.accent,
          );

      fileGateway.pickedFile = PickedBackupFile(
        name: sourceBackup.fileName,
        bytes: sourceBackup.bytes,
      );

      await tester.pumpWidget(buildApp());

      await scrollToKey(tester, const Key('restore-backup-button'));

      await tester.tap(find.byKey(const Key('restore-backup-button')));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('backup-info-continue-button')));

      await tester.pumpAndSettle();

      expect(
        find.textContaining('Picture restore is not available'),
        findsOneWidget,
      );

      // No safety backup means destructive restore
      // never started.
      expect(fileGateway.savedBackups, isEmpty);
    },
  );
}
