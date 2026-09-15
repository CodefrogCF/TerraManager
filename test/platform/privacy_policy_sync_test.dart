import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String normalizeLineEndings(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }

  test('public privacy pages match both bundled languages', () {
    const synchronizedDocuments = {
      'PRIVACY.md': 'docs/privacy/index.md',
      'PRIVACY.de.md': 'docs/privacy/de/index.md',
    };

    for (final entry in synchronizedDocuments.entries) {
      final bundled = normalizeLineEndings(File(entry.key).readAsStringSync());
      final web = normalizeLineEndings(File(entry.value).readAsStringSync());
      final withoutFrontMatter = web.replaceFirst(
        RegExp(r'^---\s*\n.*?\n---\s*\n', dotAll: true),
        '',
      );

      expect(
        normalizeLineEndings(withoutFrontMatter),
        bundled,
        reason: entry.key,
      );
    }
  });

  test('localized policies keep identity and effective date aligned', () {
    final english = File('PRIVACY.md').readAsStringSync();
    final german = File('PRIVACY.de.md').readAsStringSync();

    for (final document in [english, german]) {
      expect(document, contains('TerraManager'));
      expect(document, contains('Codefrog'));
      expect(document, contains('2026'));
      expect(document, contains('INTERNET'));
    }
    expect(english, contains('September 15, 2026'));
    expect(german, contains('15. September 2026'));
  });
}
