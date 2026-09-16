import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  String normalize(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }

  String withoutFrontMatter(String value) {
    return value.replaceFirst(
      RegExp(r'^---\s*\n.*?\n---\s*\n', dotAll: true),
      '',
    );
  }

  test('configures GitHub Pages for the TerraManager project path', () {
    final config = read('docs/_config.yml');
    final germanEntry = read('docs/index.md');
    final englishEntry = read('docs/en/index.md');
    final layout = read('docs/_layouts/home.html');

    expect(config, contains('url: "https://codefrogcf.github.io"'));
    expect(config, contains('baseurl: "/TerraManager"'));
    expect(germanEntry, contains('layout: home'));
    expect(germanEntry, contains('lang: de'));
    expect(germanEntry, contains('permalink: /'));
    expect(englishEntry, contains('layout: home'));
    expect(englishEntry, contains('lang: en'));
    expect(englishEntry, contains('permalink: /en/'));
    expect(layout, contains("site.data.home[page.lang]"));
    expect(layout, contains('| relative_url'));
    expect(layout, contains('| absolute_url'));
  });

  test('shares one complete localized homepage structure', () {
    final content = read('docs/_data/home.yml');
    final layout = read('docs/_layouts/home.html');

    for (final marker in [
      'de:',
      'en:',
      'Deine Terrarien. Deine Daten.',
      'Your terrariums. Your data.',
      'TerraManager herunterladen',
      'Download TerraManager',
      'Datenschutzerklärung lesen',
      'Read the Privacy Policy',
      'Google Play',
      'GitHub Releases',
    ]) {
      expect(content, contains(marker), reason: marker);
    }

    expect(RegExp(r'<h1>').allMatches(layout), hasLength(1));
    expect(layout, contains('{% for feature in t.features %}'));
    expect(layout, contains('{% for guide in t.guides.cards %}'));
    expect(layout, contains('alternate_path'));
  });

  test('keeps homepage delivery static and privacy friendly', () {
    final layout = read('docs/_layouts/home.html').toLowerCase();
    final styles = read('docs/assets/css/home.css').toLowerCase();

    expect(layout, isNot(contains('<script')));
    expect(layout, isNot(contains('analytics')));
    expect(layout, isNot(contains('googletag')));
    expect(layout, isNot(contains('fonts.googleapis')));
    expect(layout, isNot(contains('cookie')));
    expect(styles, isNot(contains('@import')));
    expect(styles, isNot(contains('url(http')));
  });

  test('includes responsive, keyboard and metadata foundations', () {
    final layout = read('docs/_layouts/home.html');
    final styles = read('docs/assets/css/home.css');

    for (final marker in [
      'class="skip-link"',
      '<nav aria-label=',
      'aria-labelledby=',
      'role="img" aria-label=',
      'rel="canonical"',
      'hreflang="de"',
      'hreflang="en"',
      'property="og:title"',
      'property="og:image"',
      'name="twitter:card"',
      'rel="icon"',
    ]) {
      expect(layout, contains(marker), reason: marker);
    }

    expect(styles, contains(':focus-visible'));
    expect(styles, contains('@media (max-width: 940px)'));
    expect(styles, contains('@media (max-width: 720px)'));
    expect(styles, contains('@media (prefers-reduced-motion: reduce)'));
  });

  test('keeps every local homepage destination present', () {
    const requiredFiles = [
      'docs/assets/css/home.css',
      'docs/assets/images/app-icon.png',
      'docs/assets/images/frog.webp',
      'docs/privacy/index.md',
      'docs/privacy/de/index.md',
      'docs/license/index.md',
      'docs/installation-and-updates.md',
      'docs/testing/index.md',
      'docs/project-documentation.md',
    ];

    for (final path in requiredFiles) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('publishes the authoritative repository license locally', () {
    final repositoryLicense = normalize(read('LICENSE'));
    final publicPage = withoutFrontMatter(read('docs/license/index.md'))
        .replaceFirst('# GNU General Public License v3.0 or later', '');

    expect(normalize(publicPage), repositoryLicense);
  });
}
