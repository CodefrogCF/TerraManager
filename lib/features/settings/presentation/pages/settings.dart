import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/database/app_database.dart';
import '../../../backup/application/backup_export_service.dart';
import '../../../backup/application/backup_restore_service.dart';
import '../../../backup/application/backup_validation_exception.dart';
import '../../../backup/application/backup_validation_service.dart';
import '../../../backup/application/validated_backup.dart';
import '../../../backup/infrastructure/backup_file_service.dart';
import '../../app_accent.dart';
import '../../app_settings_controller.dart';

typedef AppVersionLoader = Future<String> Function();

class SettingsPage extends StatefulWidget {
  final AppDatabase database;

  final BackupFileGateway? backupFileGateway;
  final BackupExportService? backupExportService;
  final BackupValidationService? backupValidationService;

  final AppVersionLoader? appVersionLoader;

  final VoidCallback? onRestoreCompleted;

  const SettingsPage({
    super.key,
    required this.database,
    this.backupFileGateway,
    this.backupExportService,
    this.backupValidationService,
    this.appVersionLoader,
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

    final packageInfo = await PackageInfo.fromPlatform();

    return packageInfo.version;
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
      );

      await _backupFileGateway.saveBackup(backup);

      if (!mounted) {
        return;
      }

      _showMessage('Backup created successfully.');
    } catch (error, stackTrace) {
      debugPrint('Backup creation failed: $error');

      debugPrintStack(
        label: 'Backup creation stack trace',
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Failed to create backup.', error: true);
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

      final confirmed = await _showRestoreConfirmation();

      if (!confirmed || !mounted) {
        return;
      }

      // User interaction is complete. The actual
      // restore operation begins now.
      setState(() {
        _backupProgressVisible = true;
      });

      final settings = AppSettingsScope.of(context);

      final appVersion = await _loadAppVersion();

      final restoreService = BackupRestoreService(
        database: widget.database,
        settingsController: settings,
        safetyBackupWriter: (safetyBackup) async {
          await _backupFileGateway.saveBackup(safetyBackup);
        },
        exportService: _backupExportService,
      );

      await restoreService.restore(
        backup: backup,
        currentAppVersion: appVersion,
      );

      widget.onRestoreCompleted?.call();

      if (!mounted) {
        return;
      }

      _showMessage('Backup restored successfully.');
    } catch (error, stackTrace) {
      debugPrint('Backup restore failed: $error');

      debugPrintStack(
        label: 'Backup restore stack trace',
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Failed to restore backup.', error: true);
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
          title: const Text('Backup Information'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Created', _formatDateTime(backup.manifest.createdAt)),
                _infoRow('App version', backup.manifest.appVersion),
                _infoRow(
                  'Backup format',
                  backup.manifest.backupFormatVersion.toString(),
                ),
                _infoRow(
                  'Database schema',
                  backup.manifest.databaseSchemaVersion.toString(),
                ),
                const Divider(),
                _infoRow('Boxes', backup.boxCount.toString()),
                _infoRow('Animals', backup.animalCount.toString()),
                _infoRow('Feeding events', backup.feedingEventCount.toString()),
                _infoRow('Pictures', backup.mediaFileCount.toString()),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('backup-info-cancel-button'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('backup-info-continue-button'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Continue'),
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

  Future<bool> _showRestoreConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('restore-confirmation-dialog'),
          title: const Text('Replace existing data?'),
          content: const Text(
            'Existing TerraManager data will be '
            'replaced by this backup.\n\n'
            'A safety backup of the current state '
            'will be created before the restore '
            'begins.\n\n'
            'This operation cannot be merged with '
            'the current data.',
          ),
          actions: [
            TextButton(
              key: const Key('restore-cancel-button'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('restore-confirm-button'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showValidationError(BackupValidationException error) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('backup-validation-error-dialog'),
          title: const Text('Invalid Backup'),
          content: Text(error.message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),

          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              key: const Key('theme-mode-selector'),
              segments: const [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_brightness),
                  label: Text('System'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Light'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Dark'),
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

          Text('Accent Color', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppAccent.values.map((accent) {
              final selected = accent == settings.accent;

              return ChoiceChip(
                key: Key('accent-${accent.name}'),
                selected: selected,
                onSelected: _backupBusy
                    ? null
                    : (_) {
                        settings.setAccent(accent);
                      },
                avatar: CircleAvatar(backgroundColor: accent.color),
                label: Text(accent.label),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          Text(
            'Changes are saved automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: 40),

          const Divider(),
          const SizedBox(height: 24),

          Text(
            'Backup & Restore',
            key: const Key('backup-section-heading'),
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 8),

          Text(
            'Create a portable TerraManager backup '
            'or replace the current local data from '
            'an existing backup.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 24),

          ListTile(
            key: const Key('create-backup-button'),
            enabled: !_backupBusy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('Create Backup'),
            subtitle: const Text(
              'Export boxes, animals, feeding '
              'events, settings and pictures.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _backupBusy ? null : _createBackup,
          ),

          const Divider(),

          ListTile(
            key: const Key('restore-backup-button'),
            enabled: !_backupBusy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore Backup'),
            subtitle: const Text(
              'Validate and replace the current '
              'local TerraManager data.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _backupBusy ? null : _restoreBackup,
          ),

          if (_backupProgressVisible) ...[
            const SizedBox(height: 24),
            const Center(
              child: CircularProgressIndicator(key: Key('backup-progress')),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
