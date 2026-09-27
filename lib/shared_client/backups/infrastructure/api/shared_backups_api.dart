import 'package:flutter/foundation.dart';
import 'package:terramanager/shared_client/backups/domain/shared_backup_file.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedBackupsApi on SharedApiTransport {
  Future<SharedBackupFile> exportBackup() async {
    final response = await requestBinary('GET', '/api/v1/admin/backups');
    final token = response.headers['x-safety-token'];
    if (token == null || token.isEmpty) {
      throw const SharedApiException(
        200,
        'invalid_response',
        'The safety backup token is missing.',
      );
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName =
        RegExp(r'filename="([^"]+)"').firstMatch(disposition)?.group(1) ??
        'TerraManager_Shared_Backup.tmbackup';
    return SharedBackupFile(response.bodyBytes, fileName, token);
  }

  Future<bool> safetyBackupRequired() async {
    final json = await requestJson(
      'GET',
      '/api/v1/admin/backups/restore-status',
    );
    final required = json['safetyBackupRequired'];
    if (required is! bool) {
      throw const SharedApiException(
        200,
        'invalid_response',
        'The server did not confirm the restore requirements.',
      );
    }
    return required;
  }

  Future<void> restoreBackup(
    Uint8List bytes,
    String? safetyToken, {
    String? legacyTimeZone,
  }) async {
    await requestBinary(
      'POST',
      '/api/v1/admin/backups/restore',
      bytes: bytes,
      timeout: const Duration(minutes: 10),
      extraHeaders: {
        'X-Safety-Token': ?safetyToken,
        'X-Backup-Time-Zone': ?legacyTimeZone,
        'X-Restore-Confirmation': 'replace-shared-collection',
      },
    );
  }
}
