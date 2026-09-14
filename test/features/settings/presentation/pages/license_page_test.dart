import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/settings/presentation/pages/license_page.dart';

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
