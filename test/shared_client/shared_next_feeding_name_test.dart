import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/settings/application/shared_account_settings.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart';
import 'package:terramanager/shared_server/settings/application/account_preferences.dart';

void main() {
  for (final grid in [false, true]) {
    testWidgets(
      'Next Feeding ${grid ? 'grid' : 'list'} respects saved account name order, updates and falls back',
      (tester) async {
        final stored = <String, dynamic>{
          ...defaultAccountPreferences,
          'next_feeding_summary_enabled': true,
          'big_picture_mode_enabled': grid,
        };
        final api = SharedApiClient(
          Uri.parse('https://test.local'),
          MockClient((request) async {
            if (request.url.path.endsWith('/login')) {
              return http.Response(
                jsonEncode({
                  'user': {'username': 'user', 'role': 'caregiver'},
                  'csrfToken': 'token',
                  'preferences': stored,
                }),
                200,
              );
            }
            stored.addAll(jsonDecode(request.body));
            return http.Response(jsonEncode({'preferences': stored}), 200);
          }),
        );
        final settings = SharedAccountSettings(api);
        addTearDown(settings.dispose);
        addTearDown(api.close);
        await api.login('user', 'password');
        final animal = <String, dynamic>{
          'id': 7,
          'status': 'active',
          'boxId': 1,
          'commonName': 'Common',
          'latinName': 'Latin species',
        };
        final due = DateTime.now()
            .toUtc()
            .add(const Duration(days: 3))
            .toIso8601String();
        final reminder = {'animalId': 7, 'dueAt': due};
        Widget app() => AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SharedAnimalsPage(
              api: api,
              boxes: const [
                {'id': 1, 'status': 'active'},
              ],
              animals: [animal],
              reminders: [reminder],
              connected: true,
              change: (_) async => true,
              onReload: () async {},
            ),
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        Finder summaryText(String name) => find.descendant(
          of: find.byKey(const Key('shared-next-feeding-summary')),
          matching: find.textContaining(name),
        );
        expect(summaryText('Common'), findsOneWidget);
        await settings.setAnimalNameOrder(AnimalNameOrder.latinNameFirst);
        await tester.pumpAndSettle();
        expect(summaryText('Latin species'), findsOneWidget);
        expect(summaryText('Common'), findsNothing);
        animal['latinName'] = ' ';
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(summaryText('Common'), findsOneWidget);
        animal['latinName'] = 'Latin species';
        animal['commonName'] = ' ';
        await settings.setAnimalNameOrder(AnimalNameOrder.commonNameFirst);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(summaryText('Latin species'), findsOneWidget);
        expect(reminder['animalId'], 7);
        expect(reminder['dueAt'], due);
      },
    );
  }
}
