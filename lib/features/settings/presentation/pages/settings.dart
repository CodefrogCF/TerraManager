import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations_context.dart';
import '../../../../l10n/app_localizations_labels.dart';
import '../../../backup/application/backup_export_service.dart';
import '../../../backup/application/backup_restore_service.dart';
import '../../../backup/application/backup_validation_exception.dart';
import '../../../backup/application/backup_validation_service.dart';
import '../../../backup/application/validated_backup.dart';
import '../../../backup/infrastructure/backup_file_service.dart';
import '../../app_accent.dart';
import '../../app_language.dart';
import '../../app_settings_controller.dart';
import '../../animal_name_order.dart';
import 'privacy_policy_page.dart';

typedef AppVersionLoader = Future<String> Function();
typedef AppInformationLoader = Future<AppInformation> Function();

class AppInformation {
  final String version;
  final String buildNumber;

  const AppInformation({required this.version, required this.buildNumber});
}

class SettingsPage extends StatefulWidget {
  final AppDatabase database;

  final BackupFileGateway? backupFileGateway;
  final BackupExportService? backupExportService;
  final BackupValidationService? backupValidationService;

  final AppVersionLoader? appVersionLoader;
  final AppInformationLoader? appInformationLoader;

  final VoidCallback? onRestoreCompleted;

  const SettingsPage({
    super.key,
    required this.database,
    this.backupFileGateway,
    this.backupExportService,
    this.backupValidationService,
    this.appVersionLoader,
    this.appInformationLoader,
    this.onRestoreCompleted,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final BackupFileGateway _backupFileGateway;
  late final BackupExportService _backupExportService;
  late final BackupValidationService _backupValidationService;

  bool _backupBusy = false;
  bool _backupProgressVisible = false;

  @override
  void initState() {
    super.initState();

    _backupFileGateway = widget.backupFileGateway ?? BackupFileService();

    _backupExportService =
        widget.backupExportService ?? BackupExportService(widget.database);

    _backupValidationService =
        widget.backupValidationService ?? BackupValidationService();
  }

  Future<String> _loadAppVersion() async {
    if (widget.appVersionLoader != null) {
      return widget.appVersionLoader!();
    }

    return (await _loadAppInformation()).version;
  }

  Future<AppInformation> _loadAppInformation() async {
    if (widget.appInformationLoader != null) {
      return widget.appInformationLoader!();
    }

    final packageInfo = await PackageInfo.fromPlatform();

    return AppInformation(
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
  }

  Future<void> _showAboutTerraManager() async {
    try {
      final information = await _loadAppInformation();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return _AboutTerraManagerDialog(information: information);
        },
      );
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.failedToLoadAppInformation, error: true);
      }
    }
  }

  Future<void> _createBackup() async {
    if (_backupBusy) {
      return;
    }

    setState(() {
      _backupBusy = true;
      _backupProgressVisible = true;
    });

    try {
      final settings = AppSettingsScope.of(context);

      final appVersion = await _loadAppVersion();

      final backup = await _backupExportService.createBackup(
        appVersion: appVersion,
        themeMode: settings.themeMode,
        accent: settings.accent,
        language: settings.language,
        animalNameOrder: settings.animalNameOrder,
        animalSortOrder: settings.animalSortOrder,
        boxSortOrder: settings.boxSortOrder,
      );

      final savedPath = await _backupFileGateway.saveBackup(backup);

      if (!mounted) {
        return;
      }

      if (savedPath == null) {
        _showMessage(context.l10n.backupCreationCancelled);

        return;
      }

      _showMessage(context.l10n.backupCreatedSuccessfully);
    } catch (error, stackTrace) {
      debugPrint('Backup creation failed: $error');

      debugPrintStack(
        label: 'Backup creation stack trace',
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      _showMessage(context.l10n.failedToCreateBackup, error: true);
    } finally {
      if (mounted) {
        setState(() {
          _backupBusy = false;
          _backupProgressVisible = false;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_backupBusy) {
      return;
    }

    setState(() {
      _backupBusy = true;
      _backupProgressVisible = true;
    });

    try {
      final picked = await _backupFileGateway.pickBackup();

      if (picked == null) {
        return;
      }

      final ValidatedBackup backup;

      try {
        backup = _backupValidationService.validate(picked.bytes);
      } on BackupValidationException catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _backupProgressVisible = false;
        });

        await _showValidationError(error);

        return;
      }

      if (!mounted) {
        return;
      }

      // Validation is complete and the application is
      // waiting for user interaction. Do not keep an
      // indeterminate progress indicator running while
      // dialogs are open.
      setState(() {
        _backupProgressVisible = false;
      });

      final continueRestore = await _showBackupInformation(backup);

      if (!continueRestore || !mounted) {
        return;
      }

      final createSafetyBackup = await _showRestoreConfirmation();

      if (createSafetyBackup == null || !mounted) {
        return;
      }

      // User interaction is complete. The actual
      // restore operation begins now.
      setState(() {
        _backupProgressVisible = true;
      });

      final settings = AppSettingsScope.of(context);

      final appVersion = createSafetyBackup ? await _loadAppVersion() : null;

      final restoreService = BackupRestoreService(
        database: widget.database,
        settingsController: settings,
        safetyBackupWriter: (safetyBackup) async {
          final savedPath = await _backupFileGateway.saveBackup(safetyBackup);

          if (savedPath == null) {
            throw StateError('Safety backup save was cancelled.');
          }
        },
        exportService: _backupExportService,
      );

      await restoreService.restore(
        backup: backup,
        currentAppVersion: appVersion,
        createSafetyBackup: createSafetyBackup,
      );

      widget.onRestoreCompleted?.call();

      if (!mounted) {
        return;
      }

      _showMessage(context.l10n.backupRestoredSuccessfully);
    } catch (error, stackTrace) {
      debugPrint('Backup restore failed: $error');

      debugPrintStack(
        label: 'Backup restore stack trace',
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      _showMessage(context.l10n.failedToRestoreBackup, error: true);
    } finally {
      if (mounted) {
        setState(() {
          _backupBusy = false;
          _backupProgressVisible = false;
        });
      }
    }
  }

  Future<bool> _showBackupInformation(ValidatedBackup backup) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('backup-info-dialog'),
          title: Text(context.l10n.backupInformation),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  context.l10n.created,
                  _formatDateTime(backup.manifest.createdAt),
                ),
                _infoRow(context.l10n.appVersion, backup.manifest.appVersion),
                _infoRow(
                  context.l10n.backupFormat,
                  backup.manifest.backupFormatVersion.toString(),
                ),
                _infoRow(
                  context.l10n.databaseSchema,
                  backup.manifest.databaseSchemaVersion.toString(),
                ),
                const Divider(),
                _infoRow(
                  context.l10n.navigationBoxes,
                  backup.boxCount.toString(),
                ),
                _infoRow(
                  context.l10n.navigationAnimals,
                  backup.animalCount.toString(),
                ),
                _infoRow(
                  context.l10n.feedingEvents,
                  backup.feedingEventCount.toString(),
                ),
                _infoRow(
                  context.l10n.pictures,
                  backup.mediaFileCount.toString(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('backup-info-cancel-button'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('backup-info-continue-button'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(context.l10n.continueAction),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<bool?> _showRestoreConfirmation() async {
    var createSafetyBackup = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              key: const Key('restore-confirmation-dialog'),
              title: Text(context.l10n.replaceExistingDataQuestion),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.replaceExistingDataWarning),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      key: const Key('create-safety-backup-checkbox'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: createSafetyBackup,
                      onChanged: (value) {
                        setDialogState(() {
                          createSafetyBackup = value ?? true;
                        });
                      },
                      title: Text(context.l10n.createSafetyBackup),
                      subtitle: Text(
                        context.l10n.createSafetyBackupDescription,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('restore-cancel-button'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  key: const Key('restore-confirm-button'),
                  onPressed: () {
                    Navigator.of(context).pop(createSafetyBackup);
                  },
                  child: Text(context.l10n.restore),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _showValidationError(BackupValidationException error) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('backup-validation-error-dialog'),
          title: Text(context.l10n.invalidBackup),
          content: Text(context.l10n.backupValidationErrorLabel(error.code)),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(context.l10n.ok),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${twoDigits(local.day)}.'
        '${twoDigits(local.month)}.'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navigationSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.l10n.appearance,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),

          Text(
            context.l10n.theme,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              key: const Key('theme-mode-selector'),
              segments: [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.settings_brightness),
                  label: Text(context.l10n.themeModeLabel(ThemeMode.system)),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode),
                  label: Text(context.l10n.themeModeLabel(ThemeMode.light)),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode),
                  label: Text(context.l10n.themeModeLabel(ThemeMode.dark)),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: _backupBusy
                  ? null
                  : (selection) {
                      settings.setThemeMode(selection.first);
                    },
            ),
          ),

          const SizedBox(height: 32),

          Text(
            context.l10n.accentColor,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          InputDecorator(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              enabled: !_backupBusy,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AppAccent>(
                key: const Key('accent-color-selector'),
                value: settings.accent,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                items: AppAccent.values.map((accent) {
                  return DropdownMenuItem<AppAccent>(
                    value: accent,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: accent.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(context.l10n.appAccentLabel(accent)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _backupBusy
                    ? null
                    : (accent) {
                        if (accent != null) {
                          settings.setAccent(accent);
                        }
                      },
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            context.l10n.animalNameOrder,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),

          Text(
            context.l10n.animalNameOrderDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AnimalNameOrder>(
              key: const Key('animal-name-order-selector'),
              showSelectedIcon: false,
              segments: AnimalNameOrder.values.map((order) {
                return ButtonSegment<AnimalNameOrder>(
                  value: order,
                  label: Text(context.l10n.animalNameOrderLabel(order)),
                );
              }).toList(),
              selected: {settings.animalNameOrder},
              onSelectionChanged: _backupBusy
                  ? null
                  : (selection) {
                      settings.setAnimalNameOrder(selection.first);
                    },
            ),
          ),

          const SizedBox(height: 32),

          Text(
            context.l10n.language,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppLanguage>(
              key: const Key('language-selector'),
              segments: AppLanguage.values.map((language) {
                return ButtonSegment<AppLanguage>(
                  value: language,
                  label: Text(context.l10n.appLanguageLabel(language)),
                );
              }).toList(),
              selected: {settings.language},
              onSelectionChanged: _backupBusy
                  ? null
                  : (selection) {
                      settings.setLanguage(selection.first);
                    },
            ),
          ),

          const SizedBox(height: 32),

          Text(
            context.l10n.changesSavedAutomatically,
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: 40),

          const Divider(),
          const SizedBox(height: 24),

          Text(
            context.l10n.backupAndRestore,
            key: const Key('backup-section-heading'),
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 8),

          Text(
            context.l10n.backupSectionDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 24),

          ListTile(
            key: const Key('create-backup-button'),
            enabled: !_backupBusy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: Text(context.l10n.createBackup),
            subtitle: Text(context.l10n.createBackupDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: _backupBusy ? null : _createBackup,
          ),

          const Divider(),

          ListTile(
            key: const Key('restore-backup-button'),
            enabled: !_backupBusy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_outlined),
            title: Text(context.l10n.restoreBackup),
            subtitle: Text(context.l10n.restoreBackupDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: _backupBusy ? null : _restoreBackup,
          ),

          if (_backupProgressVisible) ...[
            const SizedBox(height: 24),
            const Center(
              child: CircularProgressIndicator(key: Key('backup-progress')),
            ),
          ],

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 24),

          Text(
            context.l10n.legalAndPrivacy,
            key: const Key('legal-section-heading'),
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 8),

          ListTile(
            key: const Key('privacy-policy-tile'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(context.l10n.privacyPolicyTitle),
            subtitle: Text(context.l10n.privacyPolicySubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PrivacyPolicyPage(title: context.l10n.privacyPolicyTitle),
                ),
              );
            },
          ),

          const Divider(),

          ListTile(
            key: const Key('about-terramanager-tile'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.aboutTerraManager),
            subtitle: Text(context.l10n.aboutTerraManagerSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAboutTerraManager,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _AboutTerraManagerDialog extends StatefulWidget {
  final AppInformation information;

  const _AboutTerraManagerDialog({required this.information});

  @override
  State<_AboutTerraManagerDialog> createState() =>
      _AboutTerraManagerDialogState();
}

class _AboutTerraManagerDialogState extends State<_AboutTerraManagerDialog> {
  static const int _requiredDeveloperTaps = 5;

  int _developerTapCount = 0;
  bool _showDeveloperSurprise = false;

  void _handleDeveloperTap() {
    if (_showDeveloperSurprise) {
      return;
    }

    _developerTapCount += 1;

    if (_developerTapCount >= _requiredDeveloperTaps) {
      setState(() {
        _showDeveloperSurprise = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('about-terramanager-dialog'),
      title: Text(context.l10n.aboutTerraManager),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AboutInformationRow(
              label: context.l10n.version,
              value: widget.information.version,
            ),
            const SizedBox(height: 12),
            _AboutInformationRow(
              label: context.l10n.buildNumber,
              value: widget.information.buildNumber,
            ),
            const SizedBox(height: 12),
            _AboutInformationRow(
              label: context.l10n.developer,
              value: 'Codefrog',
              valueKey: const Key('developer-name'),
              onValueTap: _handleDeveloperTap,
            ),
            if (_showDeveloperSurprise) ...[
              const SizedBox(height: 16),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/pictures/frog.webp',
                    key: const Key('developer-surprise-image'),
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const Key('close-about-terramanager-button'),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.ok),
        ),
      ],
    );
  }
}

class _AboutInformationRow extends StatelessWidget {
  final String label;
  final String value;
  final Key? valueKey;
  final VoidCallback? onValueTap;

  const _AboutInformationRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.onValueTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget valueWidget;

    if (onValueTap == null) {
      valueWidget = SelectableText(value, textAlign: TextAlign.end);
    } else {
      valueWidget = GestureDetector(
        key: valueKey,
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onValueTap,
        child: Text(value, textAlign: TextAlign.end),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(width: 24),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: valueWidget),
        ),
      ],
    );
  }
}
