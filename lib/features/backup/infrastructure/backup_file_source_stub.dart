import 'package:file_picker/file_picker.dart';

import '../application/backup_validation_service.dart';
import '../application/encrypted_backup_container.dart';
import '../application/validated_backup.dart';

Future<ValidatedBackup> validatePickedBackup(
  PlatformFile file,
  BackupValidationService validator,
) async => validator.validate(await file.readAsBytes());

Future<bool> isPickedBackupEncrypted(PlatformFile file) async {
  final bytes = await file.readAsBytes();
  return EncryptedBackupContainer.hasEncryptedHeader(bytes.take(8).toList());
}

Future<ValidatedBackup> validatePickedBackupEncrypted(
  PlatformFile file,
  BackupValidationService validator,
  String password,
) async => validator.validate(
  await EncryptedBackupContainer.decryptBytes(
    await file.readAsBytes(),
    password: password,
  ),
);
