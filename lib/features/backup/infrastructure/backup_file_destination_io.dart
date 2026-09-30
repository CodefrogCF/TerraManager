import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';

import '../application/backup_export_result.dart';
import '../application/encrypted_backup_container.dart';

Future<String?> saveGeneratedEncryptedBackupToFile(
  BackupArchiveWriter writer, {
  required String password,
  Future<Directory> Function()? createTemporaryDirectory,
  Future<String?> Function(String name, String path)? saveFromPath,
}) async {
  final directory = await (createTemporaryDirectory == null
      ? Directory.systemTemp.createTemp('terramanager-encrypted-backup-')
      : createTemporaryDirectory());
  OutputFileStream? output;
  EncryptedBackupOutputStream? encrypted;
  try {
    final path =
        '${directory.path}${Platform.pathSeparator}collection.tmbackup';
    output = OutputFileStream(path);
    encrypted = await EncryptedBackupContainer.newOutput(
      output,
      password: password,
    );
    final metadata = await writer(encrypted);
    encrypted.finish();
    await output.close();
    return await (saveFromPath == null
        ? FileSaver.instance.saveAs(
            name: metadata.fileName,
            filePath: path,
            includeExtension: false,
            mimeType: MimeType.custom,
            customMimeType: 'application/vnd.terramanager.backup+encrypted',
          )
        : saveFromPath(metadata.fileName, path));
  } finally {
    encrypted?.dispose();
    try {
      if (output != null) await output.close();
    } finally {
      await directory.delete(recursive: true);
    }
  }
}

/// Spools a portable ZIP to a private temporary directory before Save As.
/// The temporary plaintext archive is removed on success, cancellation or
/// failure. This path is used only on native platforms.
Future<String?> saveGeneratedBackupToFile(
  BackupArchiveWriter writer, {
  Future<Directory> Function()? createTemporaryDirectory,
  Future<String?> Function(String name, String path)? saveFromPath,
}) async {
  final directory = await (createTemporaryDirectory == null
      ? Directory.systemTemp.createTemp('terramanager-backup-')
      : createTemporaryDirectory());
  OutputFileStream? output;
  try {
    final path =
        '${directory.path}${Platform.pathSeparator}collection.tmbackup';
    output = OutputFileStream(path);
    final metadata = await writer(output);
    await output.close();
    return await (saveFromPath == null
        ? FileSaver.instance.saveAs(
            name: metadata.fileName,
            filePath: path,
            includeExtension: false,
            mimeType: MimeType.custom,
            customMimeType: 'application/vnd.terramanager.backup+zip',
          )
        : saveFromPath(metadata.fileName, path));
  } finally {
    try {
      if (output != null) await output.close();
    } finally {
      await directory.delete(recursive: true);
    }
  }
}
