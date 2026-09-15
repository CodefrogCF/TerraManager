import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/settings/presentation/pages/license_page.dart';

void main() {
  test('bundles the authoritative repository license without a duplicate', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final license = File(AppLicensePage.licenseAssetPath).readAsStringSync();

    expect(AppLicensePage.licenseAssetPath, 'LICENSE');
    expect(pubspec, contains('      - LICENSE'));
    expect(pubspec, contains('      - PRIVACY.de.md'));
    expect(license, contains('GNU GENERAL PUBLIC LICENSE'));
    expect(license, contains('Version 3, 29 June 2007'));
    expect(license, contains('END OF TERMS AND CONDITIONS'));
  });
}
