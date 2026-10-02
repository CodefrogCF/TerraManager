import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';
import 'package:terramanager/features/backup/infrastructure/backup_file_service.dart';
import 'package:terramanager/features/backup/presentation/backup_password_dialog.dart';
import 'package:terramanager/shared_client/backups/infrastructure/streamed_backup_save_support_stub.dart'
    if (dart.library.js_interop) 'package:terramanager/shared_client/backups/infrastructure/streamed_backup_save_support_web.dart'
    as stream_support;
import 'package:terramanager/shared_client/backups/presentation/widgets/shared_legacy_backup_dialog.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/shared/presentation/shared_text.dart';

class SharedBackupSection extends StatefulWidget {
  const SharedBackupSection({
    super.key,
    required this.api,
    required this.connected,
    required this.onRestored,
    this.onBackupBusyChanged,
  });

  final SharedApiClient api;
  final bool connected;
  final Future<void> Function() onRestored;
  final ValueChanged<bool>? onBackupBusyChanged;

  @override
  State<SharedBackupSection> createState() => _SharedBackupSectionState();
}

class _SharedBackupSectionState extends State<SharedBackupSection> {
  bool _busy = false;
  String? _safetyToken;
  bool _safetyEncrypted = false;

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _streamedBackupName() {
    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'TerraManager_Shared_Backup_'
        '${now.year}-${twoDigits(now.month)}-${twoDigits(now.day)}_'
        '${twoDigits(now.hour)}-${twoDigits(now.minute)}.tmbackup';
  }

  Future<void> _export() async {
    if (_busy || !widget.connected) return;
    final protection = await chooseBackupProtection(context);
    if (protection == null || !mounted) return;
    setState(() => _busy = true);
    widget.onBackupBusyChanged?.call(true);
    try {
      String? safetyToken;
      if (stream_support.supportsStreamedBackupSaving) {
        final fileName = _streamedBackupName();
        safetyToken = await widget.api.exportBackupTo((bytes) async {
          final saved = await FileSaver.instance.saveAsStream(
            name: fileName,
            stream: protection.encrypted
                ? EncryptedBackupContainer.encryptStream(
                    bytes,
                    password: protection.password!,
                  )
                : bytes,
            includeExtension: false,
            mimeType: MimeType.custom,
            customMimeType: 'application/vnd.terramanager.backup+zip',
          );
          return saved != null;
        });
      } else {
        final backup = await widget.api.exportBackup();
        final saved = await FileSaver.instance.saveAs(
          name: backup.fileName,
          bytes: protection.encrypted
              ? await EncryptedBackupContainer.encryptBytes(
                  backup.bytes,
                  password: protection.password!,
                )
              : backup.bytes,
          includeExtension: false,
          mimeType: MimeType.custom,
          customMimeType: 'application/vnd.terramanager.backup+zip',
        );
        if (saved != null) safetyToken = backup.safetyToken;
      }
      if (!mounted) return;
      if (safetyToken == null) {
        _message(
          sharedText(
            context,
            'Backup save cancelled.',
            'Sicherung wurde nicht gespeichert.',
          ),
        );
        return;
      }
      setState(() {
        _safetyToken = safetyToken;
        _safetyEncrypted = protection.encrypted;
      });
      _message(
        sharedText(
          context,
          'Shared collection saved. This copy can protect you before a restore.',
          'Gemeinsame Daten gespeichert. Diese Kopie schützt vor einer Wiederherstellung.',
        ),
      );
    } catch (error) {
      if (mounted) {
        _message(
          stream_support.isStreamSaveCancellation(error)
              ? sharedText(
                  context,
                  'Backup save cancelled.',
                  'Sicherung wurde nicht gespeichert.',
                )
              : error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBackupBusyChanged?.call(false);
    }
  }

  Future<void> _restore() async {
    if (_busy || !widget.connected) return;
    final token = _safetyToken;
    setState(() => _busy = true);
    widget.onBackupBusyChanged?.call(true);
    try {
      final requiresSafety = await widget.api.safetyBackupRequired();
      if (!mounted) return;
      if (requiresSafety && token == null) {
        _message(
          sharedText(
            context,
            'The server contains collection data. Save a current safety backup first.',
            'Der Server enthält Sammlungsdaten. Speichere zuerst eine aktuelle Sicherheitskopie.',
          ),
        );
        return;
      }
      final picked = await BackupFileService().pickBackup();
      if (picked == null || !mounted) return;
      const maxImportBytes = 256 * 1024 * 1024;
      final pickedLength = await picked.length();
      if (!mounted) return;
      if (pickedLength > maxImportBytes) {
        _message(
          sharedText(
            context,
            'This backup exceeds the 256 MiB import limit.',
            'Diese Sicherung überschreitet die Importgrenze von 256 MiB.',
          ),
        );
        return;
      }
      final encrypted = await picked.isEncrypted;
      if (!mounted) return;
      if (encrypted && requiresSafety && !_safetyEncrypted) {
        _message(
          sharedText(
            context,
            'Save a password-protected safety backup before restoring an encrypted file.',
            'Speichere vor der Wiederherstellung einer verschlüsselten Datei eine passwortgeschützte Sicherheitskopie.',
          ),
        );
        return;
      }
      final selectedBytes = await picked.readAsBytes();
      final Uint8List backupBytes;
      if (encrypted) {
        if (!mounted) return;
        final password = await askBackupPassword(context);
        if (password == null || !mounted) return;
        backupBytes = await EncryptedBackupContainer.decryptInPlace(
          selectedBytes,
          password: password,
        );
      } else {
        backupBytes = selectedBytes;
      }
      if (!mounted) return;
      if (backupBytes.length > maxImportBytes) {
        _message(
          sharedText(
            context,
            'This backup exceeds the 256 MiB import limit.',
            'Diese Sicherung überschreitet die Importgrenze von 256 MiB.',
          ),
        );
        return;
      }
      var validated = BackupValidationService(
        maxExpandedBytes: 512 * 1024 * 1024,
      ).validatePreview(backupBytes);
      if (!mounted) return;
      String? legacyTimeZone;
      if (validated.hasLegacyTimestamps) {
        legacyTimeZone = await selectLegacyBackupTimeZone(context);
        if (legacyTimeZone == null || !mounted) return;
        validated = BackupValidationService(
          maxExpandedBytes: 512 * 1024 * 1024,
          legacyTimeZone: legacyTimeZone,
          requireLegacyTimeZone: true,
        ).validatePreview(backupBytes);
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            sharedText(
              dialogContext,
              'Replace the shared collection?',
              'Gemeinsame Daten ersetzen?',
            ),
          ),
          content: Text(
            sharedText(
              dialogContext,
              'The selected backup contains ${validated.boxCount} Boxes and '
                  '${validated.animalCount} Animals. All current shared records '
                  'and pictures will be replaced. Account preferences and '
                  'caregiver accounts remain unchanged. '
                  '${requiresSafety ? 'A current safety backup protects the existing collection.' : 'The server confirmed an empty collection; no safety backup is needed. This is checked again before replacement.'}',
              'Die Sicherung enthält ${validated.boxCount} Boxen und '
                  '${validated.animalCount} Tiere. Alle aktuellen gemeinsamen '
                  'Einträge und Bilder werden ersetzt. Kontoeinstellungen '
                  'und Betreuungskonten bleiben unverändert. '
                  '${requiresSafety ? 'Eine aktuelle Sicherheitskopie schützt die bestehende Sammlung.' : 'Der Server hat eine leere Sammlung bestätigt; eine Sicherheitskopie ist nicht erforderlich. Dies wird vor dem Ersetzen erneut geprüft.'}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(sharedText(dialogContext, 'Cancel', 'Abbrechen')),
            ),
            FilledButton(
              key: const Key('shared-confirm-restore'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                sharedText(
                  dialogContext,
                  'Replace shared data',
                  'Gemeinsame Daten ersetzen',
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.api.restoreBackup(
        backupBytes,
        token,
        legacyTimeZone: legacyTimeZone,
      );
      if (!mounted) return;
      setState(() {
        _safetyToken = null;
        _safetyEncrypted = false;
      });
      await widget.onRestored();
      if (mounted) {
        _message(
          sharedText(
            context,
            'Shared collection restored.',
            'Gemeinsame Daten wiederhergestellt.',
          ),
        );
      }
    } on SharedConnectionException {
      if (mounted) {
        _message(
          sharedText(
            context,
            'No restore confirmation was received. The server may still be restoring. Wait, reload, and check the collection before trying again.',
            'Keine Bestätigung für die Wiederherstellung erhalten. Der Server arbeitet möglicherweise noch. Warte, lade neu und prüfe die Sammlung, bevor du es erneut versuchst.',
          ),
        );
      }
    } on EncryptedBackupException catch (error) {
      if (mounted) {
        _message(
          error.code == EncryptedBackupError.authenticationFailed
              ? sharedText(
                  context,
                  'Incorrect password or modified/damaged backup.',
                  'Falsches Passwort oder veränderte/beschädigte Sicherung.',
                )
              : error.message,
        );
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBackupBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        key: const Key('shared-create-backup-button'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.download_outlined),
        title: Text(
          sharedText(
            context,
            'Save shared backup',
            'Gemeinsame Sicherung speichern',
          ),
        ),
        subtitle: Text(
          sharedText(
            context,
            'Exports all shared records and pictures. Personal browser settings and caregiver accounts are excluded.',
            'Exportiert alle gemeinsamen Einträge und Bilder. Persönliche Kontoeinstellungen und Betreuungskonten sind ausgenommen.',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy || !widget.connected ? null : _export,
      ),
      const Divider(),
      ListTile(
        key: const Key('shared-restore-backup-button'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.restore_outlined),
        title: Text(
          sharedText(
            context,
            'Restore shared backup',
            'Gemeinsame Sicherung wiederherstellen',
          ),
        ),
        subtitle: Text(
          sharedText(
            context,
            'Select a compatible .tmbackup file. A current safety backup is required when the server contains collection data; an empty collection needs none.',
            'Eine kompatible .tmbackup-Datei wählen. Enthält der Server Sammlungsdaten, ist eine aktuelle Sicherheitskopie erforderlich; bei einer leeren Sammlung entfällt sie.',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy || !widget.connected ? null : _restore,
      ),
      if (_busy) ...[
        const SizedBox(height: 16),
        const LinearProgressIndicator(key: Key('shared-backup-progress')),
      ],
    ],
  );
}
