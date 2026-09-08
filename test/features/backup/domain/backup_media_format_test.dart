import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/backup/domain/backup_media_format.dart';

void main() {
  test('keeps matching legacy and optimized filename extensions', () {
    expect(
      BackupMediaFormat.extensionForExport(
        source: 'legacy-animal.JPEG',
        mimeType: 'image/jpeg',
      ),
      'jpeg',
    );
    expect(
      BackupMediaFormat.extensionForExport(
        source: r'C:\pictures\box.PNG?cache=1',
        mimeType: 'image/png',
      ),
      'png',
    );
    expect(
      BackupMediaFormat.extensionForExport(
        source: 'normalized-animal.webp',
        mimeType: 'image/webp',
      ),
      'webp',
    );
  });

  test('uses known MIME type when filename metadata is stale', () {
    expect(
      BackupMediaFormat.extensionForExport(
        source: 'animal.jpg',
        mimeType: 'image/webp',
      ),
      'webp',
    );
    expect(
      BackupMediaFormat.extensionForExport(
        source: 'picture-without-extension',
        mimeType: 'image/png',
      ),
      'png',
    );
  });

  test('maps portable legacy and optimized filenames to MIME types', () {
    expect(
      BackupMediaFormat.mimeTypeFromFileName('media/animals/1.jpg'),
      'image/jpeg',
    );
    expect(
      BackupMediaFormat.mimeTypeFromFileName('media/boxes/2.JPEG'),
      'image/jpeg',
    );
    expect(
      BackupMediaFormat.mimeTypeFromFileName('media/animals/3.png'),
      'image/png',
    );
    expect(
      BackupMediaFormat.mimeTypeFromFileName('media/boxes/4.webp'),
      'image/webp',
    );
  });

  test('keeps the existing fallback for unknown legacy media', () {
    expect(
      BackupMediaFormat.extensionForExport(
        source: 'legacy-picture.raw',
        mimeType: 'application/octet-stream',
      ),
      BackupMediaFormat.fallbackExtension,
    );
    expect(
      BackupMediaFormat.mimeTypeFromFileName('media/animals/1.img'),
      BackupMediaFormat.fallbackMimeType,
    );
  });
}
