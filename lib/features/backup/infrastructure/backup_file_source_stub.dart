import 'package:file_picker/file_picker.dart';

import '../application/backup_validation_service.dart';
import '../application/validated_backup.dart';

Future<ValidatedBackup> validatePickedBackup(
  PlatformFile file,
  BackupValidationService validator,
) async => validator.validate(await file.readAsBytes());
