import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_collection_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('archived Box context menu works in list and Big Picture', (
    tester,
  ) async {
    final settings = AppSettingsController();
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((_) async => http.Response('{}', 404)),
    );
    addTearDown(settings.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SharedBoxesPage(
            api: api,
            boxes: const [
              {'id': 1, 'name': 'Archive', 'status': 'archived'},
            ],
            animals: const [],
            connected: true,
            change: (_) async => true,
            onReload: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('box-archive-button')));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('box-context-menu-button-1'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Open details'), findsOneWidget);
    expect(find.text('Restore Box'), findsOneWidget);
    expect(find.text('Delete Box'), findsNothing);
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shared-big-picture-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('box-big-picture-1')), findsOneWidget);
    await tester.longPress(find.byKey(const Key('box-context-menu-region-1')));
    await tester.pumpAndSettle();
    expect(find.text('Restore Box'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archived Animal menu offers restore without permanent delete', (
    tester,
  ) async {
    final settings = AppSettingsController();
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((_) async => http.Response('{}', 404)),
    );
    addTearDown(settings.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SharedAnimalsPage(
            api: api,
            boxes: const [
              {'id': 1, 'status': 'active'},
            ],
            animals: const [
              {
                'id': 2,
                'commonName': 'Archive',
                'status': 'archived',
                'boxId': 1,
              },
            ],
            connected: true,
            change: (_) async => true,
            onReload: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('animal-history-button')));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('animal-context-menu-button-2'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Open details'), findsOneWidget);
    expect(find.text('Restore Animal'), findsOneWidget);
    expect(find.text('Delete Animal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
