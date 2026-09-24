import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/presentation/widgets/shared_care_browser_link.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.codefrog.terramanager/browser');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('accepts only a server HTTPS origin and opens external browser', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      String? openedUrl;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'openExternalUrl');
            openedUrl = (call.arguments as Map)['url'] as String;
            return null;
          });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SharedCareBrowserLink())),
      );
      await tester.tap(find.byKey(const Key('shared-care-browser-link')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('shared-server-url')),
        'http://192.168.1.117',
      );
      await tester.tap(find.byKey(const Key('open-shared-server')));
      await tester.pumpAndSettle();
      expect(openedUrl, isNull);
      expect(find.byKey(const Key('shared-server-url')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('shared-server-url')),
        'https://192.168.1.117/',
      );
      await tester.tap(find.byKey(const Key('open-shared-server')));
      await tester.pumpAndSettle();

      expect(openedUrl, 'https://192.168.1.117');
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString('shared_care_browser_origin'),
        'https://192.168.1.117',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('opens the website and guide for the selected language', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final openedPages = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'openProjectPage');
            openedPages.add((call.arguments as Map)['page'] as String);
            return null;
          });

      Future<void> openLinks(Locale locale) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ProjectWebLinks()),
          ),
        );
        await tester.tap(find.byKey(const Key('project-website-link')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('project-guide-link')));
        await tester.pump();
      }

      await openLinks(const Locale('en'));
      await openLinks(const Locale('de'));
      expect(openedPages, ['website-en', 'guide-en', 'website-de', 'guide-de']);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
