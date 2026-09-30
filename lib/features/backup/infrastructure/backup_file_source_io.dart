import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import '../application/backup_validation_exception.dart';
import '../application/backup_validation_service.dart';
import '../application/validated_backup.dart';

/// Reads a native picker path directly. SAF-only selections are spooled to a
/// private temporary file, which is removed on completion or handled failure.
Future<ValidatedBackup> validatePickedBackup(
  PlatformFile file,
  BackupValidationService validator,
) async {
  try {
    final path = file.path;
    if (path != null && await File(path).exists()) {
      return validateBackupFilePath(path, validator);
    }
    return await validateBackupByteStream(file.readAsByteStream(), validator);
  } on BackupValidationException {
    rethrow;
  } catch (error) {
    throw BackupValidationException(
      code: BackupValidationErrorCode.invalidArchive,
      message: 'Backup file could not be read.',
      cause: error,
    );
  }
}

ValidatedBackup validateBackupFilePath(
  String path,
  BackupValidationService validator,
) {
  final input = InputFileStream(path);
  try {
    return validator.validateStream(input);
  } finally {
    input.closeSync();
  }
}

Future<ValidatedBackup> validateBackupByteStream(
  Stream<List<int>> bytes,
  BackupValidationService validator, {
  Future<Directory> Function()? createTemporaryDirectory,
}) async {
  final directory = await (createTemporaryDirectory == null
      ? Directory.systemTemp.createTemp('terramanager-import-')
      : createTemporaryDirectory());
  final file = File(
    '${directory.path}${Platform.pathSeparator}import.tmbackup',
  );
  try {
    final sink = file.openWrite();
    try {
      await sink.addStream(bytes);
    } catch (_) {
      // addStream may already close the sink after a source failure. Do not
      // replace that original error with a second close error.
      try {
        await sink.close();
      } catch (_) {}
      rethrow;
    }
    await sink.close();
    return validateBackupFilePath(file.path, validator);
  } finally {
    if (await file.exists()) await file.delete();
    if (await directory.exists()) await directory.delete();
  }
}
