import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/settings/application/shared_account_settings.dart';
import 'package:terramanager/shared_server/settings/application/account_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'accent': 'red',
      'theme_mode': 'dark',
      'animal_name_order': 'latinNameFirst',
    }),
  );
  test(
    'account preferences isolate shared browser and survive another client',
    () async {
      var owner = '';
      final stored = <String, Map<String, dynamic>>{
        'alice': {
          ...defaultAccountPreferences,
          'accent': 'blue',
          'animal_name_order': 'latinNameFirst',
        },
        'bob': {...defaultAccountPreferences},
      };
      SharedApiClient client() => SharedApiClient(
        Uri.parse('https://test.local'),
        MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            owner = jsonDecode(request.body)['username'];
            return http.Response(
              jsonEncode({
                'user': {'username': owner, 'role': 'caregiver'},
                'csrfToken': 'token',
                'preferences': stored[owner],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/preferences')) {
            stored[owner]!.addAll(
              jsonDecode(request.body) as Map<String, dynamic>,
            );
            return http.Response(
              jsonEncode({'preferences': stored[owner]}),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      final api = client();
      final settings = SharedAccountSettings(api);
      addTearDown(settings.dispose);
      addTearDown(api.close);
      await settings.load();
      expect(settings.accent, AppAccent.green);
      expect(settings.themeMode, ThemeMode.system);
      await api.login('alice', 'password');
      expect(settings.accent, AppAccent.blue);
      expect(settings.animalNameOrder, AnimalNameOrder.latinNameFirst);
      await settings.setAccent(AppAccent.purple);
      expect(settings.accent, AppAccent.purple);
      await api.logout();
      expect(settings.accent, AppAccent.green);
      await api.login('bob', 'password');
      expect(settings.animalNameOrder, AnimalNameOrder.commonNameFirst);
      await settings.setThemeMode(ThemeMode.light);
      expect(stored['alice']!['theme_mode'], 'system');
      final second = client();
      final secondSettings = SharedAccountSettings(second);
      addTearDown(secondSettings.dispose);
      addTearDown(second.close);
      await second.login('alice', 'password');
      expect(secondSettings.accent, AppAccent.purple);
      expect(secondSettings.animalNameOrder, AnimalNameOrder.latinNameFirst);
      expect(
        (await SharedPreferences.getInstance()).getString('accent'),
        'red',
      );
    },
  );
  test('late save response cannot overwrite next account and failures keep saved values', () async {
    final pending = Completer<http.Response>();
    var writes = 0;
    final api = SharedApiClient(
      Uri.parse('https://test.local'),
      MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'user': {
                'username': jsonDecode(request.body)['username'],
                'role': 'administrator',
              },
              'csrfToken': 'token',
              'preferences': defaultAccountPreferences,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/preferences')) {
          if (++writes == 1) return pending.future;
          throw http.ClientException('offline');
        }
        return http.Response('{}', 200);
      }),
    );
    final settings = SharedAccountSettings(api);
    addTearDown(settings.dispose);
    addTearDown(api.close);
    await api.login('alice', 'password');
    final save = settings.setAccent(AppAccent.purple);
    await Future<void>.delayed(Duration.zero);
    await api.logout();
    await api.login('bob', 'password');
    pending.complete(
      http.Response(
        jsonEncode({
          'preferences': {...defaultAccountPreferences, 'accent': 'purple'},
        }),
        200,
      ),
    );
    await save;
    expect(settings.accent, AppAccent.green);
    await settings.setThemeMode(ThemeMode.dark);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.saveError, isNotNull);
  });
}
