import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String buildConfiguration;

  setUpAll(() {
    buildConfiguration = File('android/app/build.gradle.kts')
        .readAsStringSync();
  });

  test('Android release builds use a dedicated production signing config', () {
    expect(buildConfiguration, contains('signingConfigs.create("release")'));
    expect(
      buildConfiguration,
      contains('signingConfig = productionSigningConfig'),
    );
    expect(
      buildConfiguration,
      isNot(contains('signingConfigs.getByName("debug")')),
    );
    expect(buildConfiguration, contains('releaseBuildRequested'));
    expect(
      buildConfiguration,
      contains('Production signing is required for release builds.'),
    );
  });

  test('release credentials can come from a local file or environment', () {
    expect(buildConfiguration, contains('rootProject.file("key.properties")'));
    expect(buildConfiguration, contains('TERRAMANAGER_KEYSTORE_FILE'));
    expect(buildConfiguration, contains('TERRAMANAGER_KEYSTORE_PASSWORD'));
    expect(buildConfiguration, contains('TERRAMANAGER_KEY_ALIAS'));
    expect(buildConfiguration, contains('TERRAMANAGER_KEY_PASSWORD'));
  });

  test('signing secrets and common keystore formats are ignored', () {
    final ignoreRules = File('android/.gitignore').readAsStringSync();
    final example = File('android/key.properties.example').readAsStringSync();

    expect(ignoreRules, contains('key.properties'));
    expect(ignoreRules, contains('**/*.keystore'));
    expect(ignoreRules, contains('**/*.jks'));
    expect(ignoreRules, contains('**/*.p12'));
    expect(example, contains('storePassword=CHANGE_ME'));
    expect(example, contains('keyPassword=CHANGE_ME'));
    expect(example, contains('keyAlias=terramanager'));
  });
}
