import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QR ZIP and PDF export add no device or network permission', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final storageService = File(
      'lib/features/settings/infrastructure/'
      'box_qr_document_storage_service.dart',
    ).readAsStringSync();

    expect(pubspec, contains('pdf: ^3.13.0'));
    expect(pubspec, isNot(contains('permission_handler:')));
    expect(pubspec, isNot(contains('printing:')));
    expect(manifest, isNot(contains('MANAGE_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('READ_MEDIA_')));
    expect(infoPlist, isNot(contains('NSPhotoLibraryAddUsageDescription')));
    expect(storageService, contains('FileSaver.instance.saveAs'));
    expect(storageService, isNot(contains('SaverGallery')));
  });
}
