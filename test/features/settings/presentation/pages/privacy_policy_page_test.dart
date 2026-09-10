import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/settings/presentation/pages/privacy_policy_page.dart';

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
}
