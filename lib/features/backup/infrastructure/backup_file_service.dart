import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

import '../application/backup_export_result.dart';
import '../application/backup_validation_service.dart';
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

  const PickedBackupFile({required this.name, required this.bytes})
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
    return file == null ? bytes! : file.readAsBytes();
  }

  Future<ValidatedBackup> validate(BackupValidationService validator) async {
    final file = _platformFile;
    if (file != null) return source.validatePickedBackup(file, validator);
    return validator.validate(bytes!);
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

  Future<PickedBackupFile?> pickBackup();
}

class BackupFileService extends BackupFileGateway {
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
