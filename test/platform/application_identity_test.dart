import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  const applicationId = 'com.codefrog.terramanager';

  test('Android uses the permanent TerraManager identity', () {
    final buildConfiguration = File('android/app/build.gradle.kts')
        .readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final applicationName = File('android/app/src/main/res/values/strings.xml')
        .readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/com/codefrog/terramanager/MainActivity.kt',
    );

    expect(buildConfiguration, contains('namespace = "$applicationId"'));
    expect(buildConfiguration, contains('applicationId = "$applicationId"'));
    expect(manifest, contains('android:label="@string/app_name"'));
    expect(applicationName, contains('<string name="app_name">TerraManager'));
    expect(mainActivity.existsSync(), isTrue);
    expect(mainActivity.readAsStringSync(), contains('package $applicationId'));
    expect(
      File(
        'android/app/src/main/kotlin/com/example/flutter_application_1/'
        'MainActivity.kt',
      ).existsSync(),
      isFalse,
    );
  });

  test('Web manifest and page identify TerraManager', () {
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final index = File('web/index.html').readAsStringSync();

    expect(manifest['name'], 'TerraManager');
    expect(manifest['short_name'], 'TerraManager');
    expect(
      manifest['description'],
      'TerraManager is a local-first application for managing terrarium '
      'boxes, animals and feeding records.',
    );
    expect(manifest['background_color'], '#0B5D36');
    expect(manifest['theme_color'], '#0B5D36');
    expect(index, contains('<title>TerraManager</title>'));
    expect(
      index,
      contains(
        '<meta name="apple-mobile-web-app-title" content="TerraManager">',
      ),
    );
    expect(index, contains('<meta name="theme-color" content="#0B5D36">'));
  });

  test('Web icons use the expected dimensions', () {
    const iconDimensions = {
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
      'web/favicon.png': 32,
    };

    for (final entry in iconDimensions.entries) {
      final decoded = image.decodeImage(File(entry.key).readAsBytesSync());

      expect(decoded, isNotNull, reason: '${entry.key} must be a valid image');
      final decodedImage = decoded!;
      expect(decodedImage.width, entry.value, reason: entry.key);
      expect(decodedImage.height, entry.value, reason: entry.key);
    }
  });

  test('Platform identity files contain no Flutter placeholders', () {
    const platformIdentityFiles = [
      'android/app/build.gradle.kts',
      'android/app/src/main/kotlin/com/codefrog/terramanager/MainActivity.kt',
      'web/index.html',
      'web/manifest.json',
      'ios/Runner/Info.plist',
      'ios/Runner.xcodeproj/project.pbxproj',
      'macos/Runner/Configs/AppInfo.xcconfig',
      'macos/Runner.xcodeproj/project.pbxproj',
      'macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
      'linux/CMakeLists.txt',
      'linux/runner/my_application.cc',
      'windows/CMakeLists.txt',
      'windows/runner/main.cpp',
      'windows/runner/Runner.rc',
    ];

    for (final path in platformIdentityFiles) {
      final contents = File(path).readAsStringSync();

      expect(contents, isNot(contains('flutter_application_1')), reason: path);
      expect(contents, isNot(contains('Flutter Application 1')), reason: path);
      expect(contents, isNot(contains('com.example')), reason: path);
      expect(contents, isNot(contains('A new Flutter project')), reason: path);
    }
  });
}
