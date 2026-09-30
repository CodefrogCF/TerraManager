import 'package:flutter/foundation.dart';
import 'package:terramanager/shared_client/backups/domain/shared_backup_file.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

mixin SharedBackupsApi on SharedApiTransport {
  /// Starts the GET only when the destination begins reading [bytes]. This
  /// lets a browser open its save picker within the initiating user gesture.
  /// The safety token is returned only after the destination confirms a
  /// complete save.
  Future<String?> exportBackupTo(
    Future<bool> Function(Stream<List<int>> bytes) save,
  ) async {
    String? safetyToken;
    var fullyRead = false;
    final bytes = (() async* {
      final response = await requestDownload('/api/v1/admin/backups');
      final token = response.headers['x-safety-token'];
      if (token == null || token.isEmpty) {
        await response.stream.listen((_) {}).cancel();
        throw const SharedApiException(
          200,
          'invalid_response',
          'The safety backup token is missing.',
        );
      }
      safetyToken = token;
      var receivedBytes = 0;
      await for (final chunk in downloadBody(response)) {
        receivedBytes += chunk.length;
        yield chunk;
      }
      if (receivedBytes == 0) {
        throw const SharedApiException(
          200,
          'invalid_response',
          'The server returned an empty backup.',
        );
      }
      if (response.contentLength case final expectedBytes?
          when receivedBytes != expectedBytes) {
        throw const SharedApiException(
          200,
          'incomplete_backup',
          'The backup download ended before all bytes arrived.',
        );
      }
      fullyRead = true;
    })();

    if (!await save(bytes)) return null;
    final token = safetyToken;
    if (token == null || !fullyRead) {
      throw StateError('The backup destination did not save the full archive.');
    }
    return token;
  }

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
