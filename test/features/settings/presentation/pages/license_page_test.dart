import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/settings/presentation/pages/license_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('renders the complete bundled license offline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppLicensePage(title: 'License')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('license-page')), findsOneWidget);
    expect(find.byKey(const Key('license-content')), findsOneWidget);
    expect(find.text('TerraManager'), findsOneWidget);
    expect(find.textContaining('GNU GENERAL PUBLIC LICENSE'), findsWidgets);
    expect(find.textContaining('GPL-3.0-or-later'), findsOneWidget);
  });

  testWidgets('renders license references without an external launcher', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppLicensePage(
          title: 'License',
          licenseText: 'GNU project: https://www.gnu.org/licenses/gpl-3.0.html',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('https://www.gnu.org/licenses/gpl-3.0.html'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('German view explains authority and keeps full GPL offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppLicensePage(
          title: 'Lizenz',
          licenseText:
              'GNU GENERAL PUBLIC LICENSE\n\nEND OF TERMS AND CONDITIONS',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final document = tester.widget<Markdown>(
      find.byKey(const Key('license-content')),
    );
    expect(document.data, contains('Copyright © 2026 Codefrog'));
    expect(document.data, contains('rechtlich maßgeblich'));
    expect(document.data, contains('GNU GENERAL PUBLIC LICENSE'));
    expect(document.data, contains('END OF TERMS AND CONDITIONS'));
  });

  testWidgets('remains scrollable with large accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
          child: const AppLicensePage(
            title: 'License',
            licenseText: '# License\n\nReadable offline license text.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
