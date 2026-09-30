import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import '../application/backup_validation_exception.dart';
import '../application/backup_validation_service.dart';
import '../application/validated_backup.dart';
import '../application/encrypted_backup_container.dart';
import 'encrypted_backup_file_io.dart';

Future<bool> isPickedBackupEncrypted(PlatformFile file) async {
  final path = file.path;
  if (path != null && await File(path).exists()) {
    final input = await File(path).open();
    try {
      return EncryptedBackupContainer.hasEncryptedHeader(
        await input.read(EncryptedBackupContainer.magic.length),
      );
    } finally {
      await input.close();
    }
  }
  final iterator = StreamIterator(file.readAsByteStream());
  final prefix = <int>[];
  try {
    while (prefix.length < EncryptedBackupContainer.magic.length &&
        await iterator.moveNext()) {
      prefix.addAll(
        iterator.current.take(
          EncryptedBackupContainer.magic.length - prefix.length,
        ),
      );
    }
    return EncryptedBackupContainer.hasEncryptedHeader(prefix);
  } finally {
    await iterator.cancel();
  }
}

Future<ValidatedBackup> validatePickedBackupEncrypted(
  PlatformFile file,
  BackupValidationService validator,
  String password,
) async {
  final path = file.path;
  if (path != null && await File(path).exists()) {
    return validateEncryptedBackupFilePath(path, validator, password);
  }
  final directory = await Directory.systemTemp.createTemp(
    'terramanager-encrypted-import-',
  );
  final staged = File(
    '${directory.path}${Platform.pathSeparator}encrypted.tmbackup',
  );
  try {
    final sink = staged.openWrite();
    try {
      await sink.addStream(file.readAsByteStream());
    } finally {
      await sink.close();
    }
    final backup = await validateEncryptedBackupFilePath(
      staged.path,
      validator,
      password,
    );
    return ValidatedBackup(
      manifest: backup.manifest,
      data: backup.data,
      settings: backup.settings,
      hasLegacyTimestamps: backup.hasLegacyTimestamps,
      mediaFiles: backup.mediaFiles,
      mediaPaths: backup.mediaPaths,
      mediaReader: backup.readMedia,
      disposer: () {
        backup.dispose();
        directory.deleteSync(recursive: true);
      },
    );
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
}

Future<ValidatedBackup> validateEncryptedBackupFilePath(
  String path,
  BackupValidationService validator,
  String password,
) async {
  final encrypted = await EncryptedBackupFile.open(path, password: password);
  try {
    return validator.validateLazyStream(
      encrypted.openZipStream(),
      onDispose: encrypted.close,
    );
  } catch (_) {
    encrypted.close();
    rethrow;
  }
}

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
