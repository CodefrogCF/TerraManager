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
      expect(document, contains('INTERNET'));
    }
    const months = {
      'January': 'Januar',
      'February': 'Februar',
      'March': 'März',
      'April': 'April',
      'May': 'Mai',
      'June': 'Juni',
      'July': 'Juli',
      'August': 'August',
      'September': 'September',
      'October': 'Oktober',
      'November': 'November',
      'December': 'Dezember',
    };
    final englishDate = RegExp(
      r'^\*\*Effective date:\*\* ([A-Za-z]+) (\d{1,2}), (\d{4})$',
      multiLine: true,
    ).firstMatch(english);
    final germanDate = RegExp(
      r'^\*\*Gültig ab:\*\* (\d{1,2})\. ([A-Za-zÄÖÜäöü]+) (\d{4})$',
      multiLine: true,
    ).firstMatch(german);

    expect(englishDate, isNotNull);
    expect(germanDate, isNotNull);
    expect(months[englishDate!.group(1)], germanDate!.group(2));
    expect(englishDate.group(2), germanDate.group(1));
    expect(englishDate.group(3), germanDate.group(3));
    expect(english, contains('Shared Care Web'));
    expect(german, contains('Shared-Care-Webmodus'));
  });
}
