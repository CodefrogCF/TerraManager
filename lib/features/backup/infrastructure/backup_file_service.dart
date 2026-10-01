import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

import '../application/backup_export_result.dart';
import '../application/backup_validation_service.dart';
import '../application/encrypted_backup_container.dart';
import '../application/validated_backup.dart';
import '../domain/backup_format.dart';
import 'backup_file_destination_stub.dart'
    if (dart.library.io) 'backup_file_destination_io.dart'
    as destination;
import 'backup_file_source_stub.dart'
    if (dart.library.io) 'backup_file_source_io.dart'
    as source;

class PickedBackupFile {
  final String name;
  final Uint8List? bytes;
  final PlatformFile? _platformFile;
  Uint8List? _cachedWebBytes;

  PickedBackupFile({required this.name, required this.bytes})
    : _platformFile = null;

  PickedBackupFile.fromPlatformFile(PlatformFile file)
    : name = file.name,
      bytes = null,
      _platformFile = file;

  Future<int> length() async {
    final file = _platformFile;
    return file == null ? bytes!.length : await file.length();
  }

  Future<Uint8List> readAsBytes() async {
    final file = _platformFile;
    if (file == null) return bytes!;
    if (kIsWeb) return _cachedWebBytes ??= await file.readAsBytes();
    return file.readAsBytes();
  }

  Future<ValidatedBackup> validate(BackupValidationService validator) async {
    final file = _platformFile;
    if (file != null && kIsWeb) return validator.validate(await readAsBytes());
    if (file != null) return source.validatePickedBackup(file, validator);
    return validator.validate(bytes!);
  }

  Future<bool> get isEncrypted async {
    final file = _platformFile;
    if (file != null && kIsWeb) {
      return EncryptedBackupContainer.hasEncryptedHeader(
        (await readAsBytes()).take(8).toList(),
      );
    }
    if (file != null) return source.isPickedBackupEncrypted(file);
    return EncryptedBackupContainer.hasEncryptedHeader(bytes!.take(8).toList());
  }

  Future<ValidatedBackup> validateEncrypted(
    BackupValidationService validator, {
    required String password,
  }) async {
    final file = _platformFile;
    if (file != null && kIsWeb) {
      return validator.validate(
        await EncryptedBackupContainer.decryptInPlace(
          await readAsBytes(),
          password: password,
        ),
      );
    }
    if (file != null) {
      return source.validatePickedBackupEncrypted(file, validator, password);
    }
    final plain = await EncryptedBackupContainer.decryptBytes(
      bytes!,
      password: password,
    );
    return validator.validate(plain);
  }
}

abstract class BackupFileGateway {
  Future<String?> saveBackup(BackupExportResult backup);

  /// Fakes and browser implementations can retain the existing byte path.
  Future<String?> saveGeneratedBackup(BackupArchiveWriter writer) async {
    final output = OutputMemoryStream();
    final metadata = await writer(output);
    return saveBackup(
      BackupExportResult.fromMetadata(
        bytes: output.getBytes(),
        metadata: metadata,
      ),
    );
  }

  Future<String?> saveGeneratedEncryptedBackup(
    BackupArchiveWriter writer, {
    required String password,
  }) async {
    final output = OutputMemoryStream();
    final encrypted = await EncryptedBackupContainer.newOutput(
      output,
      password: password,
    );
    try {
      final metadata = await writer(encrypted);
      encrypted.finish();
      return await saveBackup(
        BackupExportResult.fromMetadata(
          bytes: output.getBytes(),
          metadata: metadata,
        ),
      );
    } finally {
      encrypted.dispose();
    }
  }

  Future<PickedBackupFile?> pickBackup();
}

class BackupFileService extends BackupFileGateway {
  @override
  Future<String?> saveGeneratedEncryptedBackup(
    BackupArchiveWriter writer, {
    required String password,
  }) {
    if (kIsWeb) {
      return super.saveGeneratedEncryptedBackup(writer, password: password);
    }
    return destination.saveGeneratedEncryptedBackupToFile(
      writer,
      password: password,
    );
  }

  @override
  Future<String?> saveGeneratedBackup(BackupArchiveWriter writer) {
    if (kIsWeb) return super.saveGeneratedBackup(writer);
    return destination.saveGeneratedBackupToFile(writer);
  }

  @override
  Future<String?> saveBackup(BackupExportResult backup) {
    return FileSaver.instance.saveAs(
      name: backup.fileName,
      bytes: backup.bytes,
      includeExtension: false,
      mimeType: MimeType.custom,
      customMimeType: 'application/vnd.terramanager.backup+zip',
    );
  }

  @override
  Future<PickedBackupFile?> pickBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const [BackupFormat.fileExtension],
    );

    if (file == null) {
      return null;
    }

    return PickedBackupFile.fromPlatformFile(file);
  }
}
