import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('pins the supported CI toolchain and third-party actions', () {
    final workflow = read('.github/workflows/quality-gates.yml');

    expect(workflow, contains('runs-on: ubuntu-24.04'));
    expect(workflow, contains("flutter-version: '3.47.2'"));
    expect(workflow, contains("java-version: '17'"));
    expect(
      workflow,
      contains('actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683'),
    );
    expect(
      workflow,
      contains('actions/setup-java@de7274f081f381c8f8158605e0321c36c376e2e6'),
    );
    expect(
      workflow,
      contains(
        'subosito/flutter-action@74af56c5ed2697ba4621264652728e8d217e53d3',
      ),
    );
  });

  test('runs locked formatting, analysis, test and supported build gates', () {
    final workflow = read('.github/workflows/quality-gates.yml');

    const requiredCommands = [
      'flutter pub get',
      'git diff --exit-code -- pubspec.lock',
      'flutter gen-l10n',
      'dart format --output=none --set-exit-if-changed lib test',
      'flutter analyze',
      'flutter test',
      'flutter build apk --debug',
      'flutter build web --release',
    ];

    for (final command in requiredCommands) {
      expect(workflow, contains(command), reason: command);
    }

    expect(workflow, isNot(contains('flutter build apk --release')));
    expect(workflow, isNot(contains('flutter build appbundle --release')));
  });

  test('documents dependency, signing and Kotlin migration boundaries', () {
    final baseline = read('docs/toolchain-baseline.md');
    final development = read('docs/development.md');
    final readme = read('README.md');
    final gradleProperties = read('android/gradle.properties');

    expect(baseline, contains('Flutter 3.47.2'));
    expect(baseline, contains('Eclipse Temurin 17'));
    expect(baseline, contains('`pubspec.lock`'));
    expect(baseline, contains('Android Debug APK'));
    expect(baseline, contains('private TerraManager signing key'));
    expect(baseline, contains('file_saver'));
    expect(baseline, contains('flutter_image_compress_common'));
    expect(baseline, contains('mobile_scanner'));
    expect(baseline, contains('Built-in Kotlin'));
    expect(development, contains('toolchain-baseline.md'));
    expect(readme, contains('](docs/toolchain-baseline.md)'));
    expect(gradleProperties, contains('android.newDsl=false'));
    expect(gradleProperties, contains('android.builtInKotlin=false'));
  });
}
