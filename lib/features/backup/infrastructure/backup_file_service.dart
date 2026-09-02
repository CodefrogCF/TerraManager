import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';

import '../application/backup_export_result.dart';
import '../domain/backup_format.dart';

class PickedBackupFile {
  final String name;
  final Uint8List bytes;

  const PickedBackupFile({required this.name, required this.bytes});
}

abstract class BackupFileGateway {
  Future<String?> saveBackup(BackupExportResult backup);

  Future<PickedBackupFile?> pickBackup();
}

class BackupFileService implements BackupFileGateway {
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

    final bytes = await file.readAsBytes();

    return PickedBackupFile(name: file.name, bytes: bytes);
  }
}
