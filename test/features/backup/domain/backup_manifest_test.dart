import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/backup/domain/backup_manifest.dart';

void main() {
  test('manifest survives json round trip', () {
    final original = BackupManifest(
      backupFormatVersion: 1,
      appVersion: '0.6.0',
      databaseSchemaVersion: 2,
      createdAt: DateTime.utc(2026, 9, 2, 12, 30),
    );

    final restored = BackupManifest.fromJson(original.toJson());

    expect(restored.backupFormatVersion, 1);

    expect(restored.appVersion, '0.6.0');

    expect(restored.databaseSchemaVersion, 2);

    expect(restored.createdAt, original.createdAt);
  });
}
