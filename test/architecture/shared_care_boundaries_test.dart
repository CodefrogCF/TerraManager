import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> dartFiles(String directory) =>
    Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

Iterable<String> dependencies(File file) sync* {
  final directives = RegExp(r'^(?:import|export)\b[^;]*;', multiLine: true);
  final quotedUris = RegExp(r'''['"]([^'"]+)['"]''');
  final libraryRoot = Directory('lib').absolute.uri.path;
  for (final directive in directives.allMatches(file.readAsStringSync())) {
    // Include every alternative of conditional browser/native imports.
    for (final match in quotedUris.allMatches(directive.group(0)!)) {
      final uri = match.group(1)!;
      if (Uri.parse(uri).hasScheme) {
        yield uri;
      } else {
        final target = file.absolute.uri.resolve(uri).path;
        yield target.startsWith(libraryRoot)
            ? 'package:terramanager/${target.substring(libraryRoot.length)}'
            : target;
      }
    }
  }
}

void main() {
  test(
    'Shared Care browser modules depend on APIs rather than persistence',
    () {
      final violations = <String>[];
      for (final file in dartFiles('lib/shared_client')) {
        for (final dependency in dependencies(file)) {
          if (dependency.contains('shared_server/') ||
              dependency.contains('core/database/app_database') ||
              dependency.contains('core/database/repositories/') ||
              dependency.contains('core/database/connection') ||
              dependency.startsWith('package:drift/') ||
              dependency.startsWith('package:sqlite3/')) {
            violations.add('${file.path}: $dependency');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test('server feature operations do not depend on HTTP or Flutter UI', () {
    final violations = <String>[];
    for (final file in dartFiles('lib/shared_server')) {
      if (!file.path.replaceAll('\\', '/').contains('/application/')) {
        continue;
      }
      for (final dependency in dependencies(file)) {
        if (dependency == 'dart:io' ||
            dependency.startsWith('package:flutter/') ||
            dependency.contains('shared_client/') ||
            dependency.contains('/infrastructure/http/')) {
          violations.add('${file.path}: $dependency');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('production code uses canonical feature paths, not migration exports', () {
    final legacy = <String>{};
    for (final area in ['shared_client', 'shared_server']) {
      for (final file in dartFiles('lib/$area')) {
        if (file.readAsStringSync().startsWith('// Compatibility exports')) {
          legacy.add(
            'package:terramanager/${file.path.replaceAll('\\', '/').substring(4)}',
          );
        }
      }
    }
    final violations = <String>[];
    for (final directory in ['lib', 'bin']) {
      for (final file in dartFiles(directory)) {
        for (final dependency in dependencies(file)) {
          if (legacy.contains(dependency)) {
            violations.add('${file.path}: $dependency');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
