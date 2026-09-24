import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/settings/presentation/pages/privacy_policy_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('displays the bundled privacy policy content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyPolicyPage(
          title: 'Privacy Policy',
          policyText: '''
# TerraManager Privacy Policy

TerraManager is a local-first application.

## No advertising

TerraManager does not contain advertising.
''',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacy-policy-page')), findsOneWidget);
    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.text('TerraManager Privacy Policy'), findsOneWidget);
    expect(
      find.text('TerraManager is a local-first application.'),
      findsOneWidget,
    );
    expect(find.text('No advertising'), findsOneWidget);
  });

  test('selects German explicitly and falls back to English', () {
    expect(
      PrivacyPolicyPage.assetPathForLocale(const Locale('de', 'DE')),
      PrivacyPolicyPage.germanAssetPath,
    );
    expect(
      PrivacyPolicyPage.assetPathForLocale(const Locale('en', 'US')),
      PrivacyPolicyPage.englishAssetPath,
    );
    expect(
      PrivacyPolicyPage.assetPathForLocale(const Locale('fr', 'FR')),
      PrivacyPolicyPage.englishAssetPath,
    );
  });

  testWidgets('loads the complete German privacy policy offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PrivacyPolicyPage(title: 'Datenschutzerklärung'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TerraManager Datenschutzerklärung'), findsOneWidget);
    expect(find.textContaining('Gültig ab:'), findsOneWidget);
    expect(find.textContaining('Shared-Care-Webmodus'), findsWidgets);
    expect(find.textContaining('Entwickler: Codefrog'), findsOneWidget);
    expect(find.byKey(const Key('privacy-policy-content')), findsOneWidget);
  });
}
