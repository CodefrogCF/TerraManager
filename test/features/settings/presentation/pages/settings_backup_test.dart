import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_result.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';
import 'package:terramanager/features/backup/application/validated_backup.dart';
import 'package:terramanager/features/backup/infrastructure/backup_file_service.dart';
import 'package:terramanager/features/settings/app_language.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/animal_sort_order.dart';
import 'package:terramanager/features/settings/box_sort_order.dart';
import 'package:terramanager/features/settings/presentation/pages/settings.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

class FakeBackupFileGateway extends BackupFileGateway {
  PickedBackupFile? pickedFile;
  int generatedSaveCalls = 0;
  int generatedEncryptedSaveCalls = 0;
  String? lastGeneratedEncryptedPassword;

  final List<BackupExportResult> savedBackups = [];

  @override
  Future<String?> saveGeneratedBackup(BackupArchiveWriter writer) {
    generatedSaveCalls++;
    return super.saveGeneratedBackup(writer);
  }

  @override
  Future<String?> saveGeneratedEncryptedBackup(
    BackupArchiveWriter writer, {
    required String password,
  }) {
    generatedEncryptedSaveCalls++;
    lastGeneratedEncryptedPassword = password;

    // Keep widget tests focused on the settings/UI lifecycle. The real
    // Argon2id + AES-GCM envelope is covered by encrypted_backup_container_test.
    return super.saveGeneratedBackup(writer);
  }

  @override
  Future<PickedBackupFile?> pickBackup() async {
    return pickedFile;
  }

  @override
  Future<String?> saveBackup(BackupExportResult backup) async {
    savedBackups.add(backup);

    return backup.fileName;
  }
}

class FakeAuthenticationFailureBackupFile extends PickedBackupFile {
  FakeAuthenticationFailureBackupFile({required this.onPassword})
    : super(
        name: 'encrypted-test.tmbak',
        bytes: Uint8List.fromList(EncryptedBackupContainer.magic),
      );

  final void Function(String password) onPassword;

  @override
  Future<bool> get isEncrypted async => true;

  @override
  Future<ValidatedBackup> validateEncrypted(
    BackupValidationService validator, {
    required String password,
  }) async {
    onPassword(password);
    throw const EncryptedBackupException(
      EncryptedBackupError.authenticationFailed,
      'Incorrect password or modified/damaged backup.',
    );
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

  Widget buildApp({
    VoidCallback? onRestoreCompleted,
    Locale? locale,
    TextScaler? textScaler,
  }) {
    return AppSettingsScope(
      controller: settingsController,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: SettingsPage(
          database: database,
          backupFileGateway: fileGateway,
          appVersionLoader: () async => '0.6.0',
          onRestoreCompleted: onRestoreCompleted,
        ),
      ),
    );
  }

  testWidgets('backup information title avoids an orphan on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sourceBackup = await BackupExportService(sourceDatabase).createBackup(
      appVersion: '1.0.0',
      themeMode: ThemeMode.system,
      accent: settingsController.accent,
    );
    fileGateway.pickedFile = PickedBackupFile(
      name: sourceBackup.fileName,
      bytes: sourceBackup.bytes,
    );
    await tester.pumpWidget(buildApp(locale: const Locale('de')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('restore-backup-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-backup-button')));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const Key('backup-info-dialog'));
    expect(dialog, findsOneWidget);
    final titleFinder = find.descendant(
      of: dialog,
      matching: find.byKey(const Key('backup-info-title')),
    );
    expect(titleFinder, findsOneWidget);
    for (final width in [
      280.0,
      300.0,
      320.0,
      340.0,
      360.0,
      380.0,
      400.0,
      420.0,
    ]) {
      tester.view.physicalSize = Size(width, 640);
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(titleFinder);
      expect(title.data!.replaceAll('\n', ''), 'Sicherungsinformationen');
      final context = tester.element(titleFinder);
      final painter = TextPainter(
        text: TextSpan(
          text: title.data,
          style: DefaultTextStyle.of(context).style,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: tester.getSize(titleFinder).width);
      final lines = painter.computeLineMetrics();
      final lastPosition = painter.getPositionForOffset(
        Offset(0, lines.last.baseline),
      );
      final lastRange = painter.getLineBoundary(lastPosition);
      final lastLine = title.data!
          .substring(lastRange.start, lastRange.end)
          .trim();
      expect(
        lastLine.length,
        greaterThan(1),
        reason: 'width=$width last="$lastLine"',
      );
      for (final line in lines) {
        expect(
          line.width,
          lessThanOrEqualTo(tester.getSize(titleFinder).width + 0.1),
          reason: 'Title overflows at width=$width',
        );
      }
      painter.dispose();
      expect(
        find.byKey(const Key('backup-info-cancel-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('backup-info-continue-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

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

  for (final scenario in [
    (
      name: 'German enlarged portrait',
      size: const Size(320, 700),
      scale: 2.0,
      locale: const Locale('de'),
    ),
    (
      name: 'German enlarged landscape',
      size: const Size(640, 360),
      scale: 1.5,
      locale: const Locale('de'),
    ),
    (
      name: 'English enlarged portrait',
      size: const Size(320, 700),
      scale: 2.0,
      locale: const Locale('en'),
    ),
  ]) {
    testWidgets('backup information layout ${scenario.name}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sourceBackup = await BackupExportService(sourceDatabase)
          .createBackup(
            appVersion: '1.0.0',
            themeMode: ThemeMode.system,
            accent: settingsController.accent,
          );
      fileGateway.pickedFile = PickedBackupFile(
        name: sourceBackup.fileName,
        bytes: sourceBackup.bytes,
      );
      await tester.pumpWidget(
        buildApp(
          locale: scenario.locale,
          textScaler: TextScaler.linear(scenario.scale),
        ),
      );
      await scrollToKey(tester, const Key('restore-backup-button'));
      await tester.tap(find.byKey(const Key('restore-backup-button')));
      await tester.pumpAndSettle();

      final dialog = find.byKey(const Key('backup-info-dialog'));
      final titleFinder = find.byKey(const Key('backup-info-title'));
      expect(dialog, findsOneWidget);
      expect(titleFinder, findsOneWidget);
      final title = tester.widget<Text>(titleFinder);
      final expectedTitle = scenario.locale.languageCode == 'de'
          ? 'Sicherungsinformationen'
          : 'Backup Information';
      expect(title.data!.replaceAll('\n', ''), expectedTitle);
      expect(title.semanticsLabel, expectedTitle);
      if (scenario.locale.languageCode == 'en') {
        expect(title.data, expectedTitle);
      }

      final context = tester.element(titleFinder);
      final painter = TextPainter(
        text: TextSpan(
          text: title.data,
          style: DefaultTextStyle.of(context).style,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: tester.getSize(titleFinder).width);
      final lines = painter.computeLineMetrics();
      final lastPosition = painter.getPositionForOffset(
        Offset(0, lines.last.baseline),
      );
      final lastRange = painter.getLineBoundary(lastPosition);
      final lastLine = title.data!
          .substring(lastRange.start, lastRange.end)
          .trim();
      expect(lastLine.length, greaterThan(1));
      for (final line in lines) {
        expect(
          line.width,
          lessThanOrEqualTo(tester.getSize(titleFinder).width + 0.1),
        );
      }
      painter.dispose();
      expect(
        find.byKey(const Key('backup-info-cancel-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('backup-info-continue-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('backup-info-cancel-button')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(
        find.byKey(const Key('restore-confirmation-dialog')),
        findsNothing,
      );
    });
  }

  testWidgets('creates and saves backup', (tester) async {
    await settingsController.setLanguage(AppLanguage.german);
    await settingsController.setAnimalNameOrder(AnimalNameOrder.latinNameFirst);
    await settingsController.setAnimalSortOrder(
      AnimalSortOrder.latestFeedingOldestFirst,
    );
    await settingsController.setAnimalCategoryViewEnabled(true);
    await settingsController.setBigPictureModeEnabled(true);
    await settingsController.setShowEmptyBoxesLast(true);
    await settingsController.setBoxSortOrder(BoxSortOrder.labelDescending);

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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-password-submit')));

    await pumpUntil(tester, () => fileGateway.savedBackups.length == 1);

    await tester.pump();

    expect(fileGateway.savedBackups.length, 1);

    expect(fileGateway.savedBackups.single.data.boxes.length, 1);

    expect(fileGateway.savedBackups.single.settings.language, 'german');

    expect(
      fileGateway.savedBackups.single.settings.animalNameOrder,
      'latinNameFirst',
    );

    expect(
      fileGateway.savedBackups.single.settings.boxSortOrder,
      'labelDescending',
    );

    expect(
      fileGateway.savedBackups.single.settings.animalSortOrder,
      'latestFeedingOldestFirst',
    );

    expect(
      fileGateway.savedBackups.single.settings.animalCategoryViewEnabled,
      isTrue,
    );

    expect(
      fileGateway.savedBackups.single.settings.bigPictureModeEnabled,
      isTrue,
    );
    expect(fileGateway.savedBackups.single.settings.showEmptyBoxesLast, isTrue);

    expect(find.text('Backup created successfully.'), findsOneWidget);

    expect(find.byKey(const Key('backup-progress')), findsNothing);
  });

  testWidgets(
    'protected export forwards password ephemerally and does not persist it',
    (tester) async {
      const password = 'temporary-backup-secret-2026';

      await tester.pumpWidget(buildApp());
      await scrollToKey(tester, const Key('create-backup-button'));
      await tester.tap(find.byKey(const Key('create-backup-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('backup-password-protection')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('backup-password')),
        password,
      );
      await tester.enterText(
        find.byKey(const Key('backup-password-confirmation')),
        password,
      );
      await tester.tap(find.byKey(const Key('backup-password-submit')));

      await pumpUntil(
        tester,
        () => fileGateway.generatedEncryptedSaveCalls == 1,
      );
      await tester.pump();

      expect(fileGateway.lastGeneratedEncryptedPassword, password);
      expect(fileGateway.savedBackups, hasLength(1));

      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys()) {
        expect(key.toLowerCase(), isNot(contains('backup-password')));
        expect(preferences.get(key)?.toString(), isNot(contains(password)));
      }
    },
  );

  testWidgets('wrong backup password is not written to debug logs', (
    tester,
  ) async {
    const wrongPassword = 'wrong-backup-secret-2026';
    String? submittedPassword;
    fileGateway.pickedFile = FakeAuthenticationFailureBackupFile(
      onPassword: (password) => submittedPassword = password,
    );

    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      await tester.pumpWidget(buildApp());
      await scrollToKey(tester, const Key('restore-backup-button'));
      await tester.tap(find.byKey(const Key('restore-backup-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('backup-password')),
        wrongPassword,
      );
      await tester.tap(find.byKey(const Key('backup-password-submit')));
      await pumpUntil(
        tester,
        () => find
            .text('Incorrect password or modified/damaged backup.')
            .evaluate()
            .isNotEmpty,
      );

      expect(submittedPassword, wrongPassword);
      expect(
        find.text('Incorrect password or modified/damaged backup.'),
        findsOneWidget,
      );
      final log = messages.join('\n');
      expect(log, isNot(contains(wrongPassword)));
      expect(log, isNot(contains('EncryptedBackupException')));
      expect(log, isNot(contains('authenticationFailed')));
    } finally {
      debugPrint = originalDebugPrint;
    }
  });

  testWidgets('validates confirms and restores '
      'backup without media', (tester) async {
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
      language: AppLanguage.german,
      animalNameOrder: AnimalNameOrder.latinNameFirst,
      animalSortOrder: AnimalSortOrder.ageYoungestFirst,
      animalCategoryViewEnabled: true,
      bigPictureModeEnabled: true,
      showEmptyBoxesLast: true,
      boxSortOrder: BoxSortOrder.labelDescending,
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

    final safetyBackupCheckbox = tester.widget<CheckboxListTile>(
      find.byKey(const Key('create-safety-backup-checkbox')),
    );

    expect(safetyBackupCheckbox.value, isTrue);

    await tester.tap(find.byKey(const Key('restore-confirm-button')));

    await pumpUntil(tester, () => restoreCompleted);

    await tester.pump();

    final boxes = await database.select(database.boxes).get();

    expect(boxes.length, 1);

    expect(boxes.single.qrId, 'TM:BOX:22222222-2222-4222-8222-222222222222');

    expect(restoreCompleted, isTrue);

    expect(settingsController.themeMode, ThemeMode.dark);

    expect(settingsController.language, AppLanguage.german);

    expect(settingsController.animalNameOrder, AnimalNameOrder.latinNameFirst);

    expect(
      settingsController.animalSortOrder,
      AnimalSortOrder.ageYoungestFirst,
    );

    expect(settingsController.animalCategoryViewEnabled, isTrue);

    expect(settingsController.bigPictureModeEnabled, isTrue);
    expect(settingsController.showEmptyBoxesLast, isTrue);

    expect(settingsController.boxSortOrder, BoxSortOrder.labelDescending);

    // Restore creates a safety
    // backup before replacing data.
    expect(fileGateway.savedBackups.length, 1);

    expect(
      fileGateway.savedBackups.single.data.boxes.single.qrId,
      'TM:BOX:11111111-1111-4111-8111-111111111111',
    );

    expect(fileGateway.savedBackups.single.settings.language, 'system');

    expect(
      fileGateway.savedBackups.single.settings.animalNameOrder,
      'commonNameFirst',
    );

    expect(
      fileGateway.savedBackups.single.settings.boxSortOrder,
      'labelAscending',
    );

    expect(
      fileGateway.savedBackups.single.settings.animalSortOrder,
      'createdOldestFirst',
    );

    expect(
      fileGateway.savedBackups.single.settings.animalCategoryViewEnabled,
      isFalse,
    );

    expect(
      fileGateway.savedBackups.single.settings.bigPictureModeEnabled,
      isFalse,
    );
    expect(
      fileGateway.savedBackups.single.settings.showEmptyBoxesLast,
      isFalse,
    );

    expect(find.text('Backup restored successfully.'), findsOneWidget);
  });

  testWidgets('can restore an empty database without a safety backup', (
    tester,
  ) async {
    await sourceDatabase
        .into(sourceDatabase.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:44444444-4444-4444-8444-444444444444',
          ),
        );

    final sourceBackup = await BackupExportService(sourceDatabase).createBackup(
      appVersion: '1.0.8',
      themeMode: ThemeMode.dark,
      accent: settingsController.accent,
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

    await tester.tap(find.byKey(const Key('backup-info-continue-button')));
    await tester.pumpAndSettle();

    final checkboxFinder = find.byKey(
      const Key('create-safety-backup-checkbox'),
    );

    expect(tester.widget<CheckboxListTile>(checkboxFinder).value, isTrue);

    await tester.tap(checkboxFinder);
    await tester.pump();

    expect(tester.widget<CheckboxListTile>(checkboxFinder).value, isFalse);

    await tester.tap(find.byKey(const Key('restore-confirm-button')));
    await pumpUntil(tester, () => restoreCompleted);
    await tester.pump();

    final boxes = await database.select(database.boxes).get();

    expect(boxes.length, 1);
    expect(boxes.single.qrId, 'TM:BOX:44444444-4444-4444-8444-444444444444');
    expect(fileGateway.savedBackups, isEmpty);
    expect(find.text('Backup restored successfully.'), findsOneWidget);
  });

  testWidgets('restores backup with '
      'persistent media', (tester) async {
    await database
        .into(database.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:11111111-1111-4111-8111-111111111111',
          ),
        );

    final sourceBoxId = await sourceDatabase
        .into(sourceDatabase.boxes)
        .insert(
          BoxesCompanion.insert(
            qrId: 'TM:BOX:33333333-3333-4333-8333-333333333333',
          ),
        );

    final pictureBytes = Uint8List.fromList([1, 2, 3]);

    final pictureMediaId = await MediaRepository(sourceDatabase).createMedia(
      fileName: 'animal.jpg',
      mimeType: 'image/jpeg',
      data: pictureBytes,
    );

    final sourceAnimalId = await sourceDatabase
        .into(sourceDatabase.animals)
        .insert(
          AnimalsCompanion.insert(
            boxId: drift.Value(sourceBoxId),
            commonName: 'Picture Animal',
            latinName: 'Test species',
            tempMin: 20,
            tempMax: 25,
            humidityMin: 40,
            humidityMax: 60,
            pictureMediaId: drift.Value(pictureMediaId),
          ),
        );

    final sourceBackup = await BackupExportService(sourceDatabase).createBackup(
      appVersion: '0.6.0',
      themeMode: ThemeMode.system,
      accent: settingsController.accent,
    );

    expect(sourceBackup.mediaFileCount, 1);

    expect(
      sourceBackup.data.animals.single.pictureMediaPath,
      'media/animals/'
      '$sourceAnimalId.jpg',
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

    expect(find.text('Pictures'), findsOneWidget);

    await tester.tap(find.byKey(const Key('backup-info-continue-button')));

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('restore-confirmation-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('restore-confirm-button')));

    await pumpUntil(tester, () => restoreCompleted);

    await tester.pump();

    final animals = await database.select(database.animals).get();

    expect(animals.length, 1);

    final animal = animals.single;

    expect(animal.id, sourceAnimalId);

    expect(animal.commonName, 'Picture Animal');

    expect(animal.picturePath, isNull);

    expect(animal.pictureMediaId, isNotNull);

    final mediaAssets = await database.select(database.mediaAssets).get();

    expect(mediaAssets.length, 1);

    final media = mediaAssets.single;

    expect(media.id, animal.pictureMediaId);

    expect(media.fileName, '$sourceAnimalId.jpg');

    expect(media.mimeType, 'image/jpeg');

    expect(media.data, pictureBytes);

    expect(restoreCompleted, isTrue);

    // Safety backup of the previous
    // database was saved.
    expect(fileGateway.generatedSaveCalls, 1);
    expect(fileGateway.savedBackups.length, 1);

    expect(
      fileGateway.savedBackups.single.data.boxes.single.qrId,
      'TM:BOX:11111111-1111-4111-8111-111111111111',
    );

    expect(find.text('Backup restored successfully.'), findsOneWidget);
  });
}
