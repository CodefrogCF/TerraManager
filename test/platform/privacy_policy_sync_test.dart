import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String normalizeLineEndings(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }

  test('public web privacy policy matches bundled privacy policy', () {
    final bundled = normalizeLineEndings(File('PRIVACY.md').readAsStringSync());

    final web = normalizeLineEndings(
      File('docs/privacy/index.md').readAsStringSync(),
    );

    final withoutFrontMatter = web.replaceFirst(
      RegExp(r'^---\s*\n.*?\n---\s*\n', dotAll: true),
      '',
    );

    expect(normalizeLineEndings(withoutFrontMatter), bundled);
  });
}
