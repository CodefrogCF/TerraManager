import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_collection_pages.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('shared settings group server actions and fit a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = AppSettingsController();
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((_) async => http.Response('{"accounts":[]}', 200)),
    );
    addTearDown(settings.dispose);
    addTearDown(api.close);

    Widget page(String role) => AppSettingsScope(
      controller: settings,
      child: MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SharedSettingsPage(
            api: api,
            username: 'hagen',
            role: role,
            connected: true,
            actionsEnabled: true,
            onLogout: () async {},
            onRestored: () async {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(page('administrator'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shared-theme-mode-selector')), findsOneWidget);
    expect(find.text('Übersichten'), findsNothing);
    expect(find.byKey(const Key('shared-box-sort-selector')), findsNothing);
    expect(find.byKey(const Key('shared-animal-sort-selector')), findsNothing);
    expect(find.byKey(const Key('shared-category-view-switch')), findsNothing);
    final nextFeeding = find.byKey(const Key('next-feeding-summary-switch'));
    await tester.scrollUntilVisible(nextFeeding, 200);
    expect(tester.widget<SwitchListTile>(nextFeeding).value, isFalse);
    await tester.tap(nextFeeding);
    await tester.pumpAndSettle();
    expect(settings.nextFeedingSummaryEnabled, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'next_feeding_summary_enabled',
      ),
      isTrue,
    );
    final bigPicture = find.byKey(const Key('big-picture-mode-switch'));
    await tester.scrollUntilVisible(bigPicture, 200);
    expect(find.text('Großbildmodus'), findsOneWidget);
    expect(
      tester.getTopLeft(nextFeeding).dy,
      lessThan(tester.getTopLeft(bigPicture).dy),
    );
    expect(tester.widget<SwitchListTile>(bigPicture).value, isFalse);
    await tester.tap(bigPicture);
    await tester.pumpAndSettle();
    expect(settings.bigPictureModeEnabled, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-server-section-heading')),
      500,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-server-status')),
      200,
    );
    expect(find.byKey(const Key('shared-server-status')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-create-backup-button')),
      300,
    );
    expect(
      find.byKey(const Key('shared-create-backup-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(page('caregiver'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('shared-sign-out-button')),
      500,
    );
    expect(find.byKey(const Key('shared-create-backup-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
