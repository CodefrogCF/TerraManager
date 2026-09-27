import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_box_detail_page.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_detail_page.dart';
import 'package:terramanager/shared_client/media/presentation/widgets/shared_picture_gallery.dart';
import 'package:terramanager/shared_client/care_history/presentation/pages/shared_history_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final role in ['caregiver', 'administrator']) {
    testWidgets(
      '$role deletion visibility for archived Animals, Boxes, histories and pictures',
      (tester) async {
        final api = SharedApiClient(
          Uri.parse('https://test.local'),
          MockClient((request) async {
            final path = request.url.path;
            if (path.endsWith('/login')) {
              return http.Response(
                jsonEncode({
                  'user': {'username': 'user', 'role': role},
                  'csrfToken': 'token',
                }),
                200,
              );
            }
            final payload = path.endsWith('/pictures')
                ? {
                    'pictures': [
                      {'mediaId': 42, 'isPrimary': false},
                    ],
                  }
                : path.endsWith('/weights')
                ? {
                    'weights': [
                      {
                        'id': 1,
                        'measuredAt': '2026-01-15T18:00:00Z',
                        'weightGrams': 12,
                      },
                    ],
                  }
                : path.endsWith('/shedding')
                ? {
                    'shedding': [
                      {'id': 1, 'shedAt': '2026-01-15T18:00:00Z'},
                    ],
                  }
                : path.endsWith('/feedings')
                ? {
                    'feedings': [
                      {'id': 1, 'fedAt': '2026-01-15T18:00:00Z'},
                    ],
                  }
                : path == '/api/v1/boxes/1'
                ? {
                    'box': {
                      'id': 1,
                      'status': 'archived',
                      'name': 'Archived Box',
                    },
                  }
                : path == '/api/v1/animals/1'
                ? {
                    'animal': {
                      'id': 1,
                      'status': 'archived',
                      'commonName': 'Archived Animal',
                      'latinName': 'Species',
                      'boxId': 1,
                      'tempMin': 20,
                      'tempMax': 30,
                      'humidityMin': 40,
                      'humidityMax': 60,
                    },
                  }
                : {'reminders': []};
            return http.Response(jsonEncode(payload), 200);
          }),
        );
        await api.login('user', 'password');
        final settings = AppSettingsController();
        addTearDown(api.close);
        addTearDown(settings.dispose);
        Future<void> show(Widget child) async {
          await tester.pumpWidget(
            AppSettingsScope(
              controller: settings,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: child,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<bool> change(Future<void> Function() operation) async => true;
        final expected = role == 'administrator'
            ? findsOneWidget
            : findsNothing;
        await show(
          SharedBoxDetailPage(
            api: api,
            id: 1,
            boxes: const [],
            animals: const [],
            connected: true,
            change: change,
          ),
        );
        await tester.scrollUntilVisible(find.text('Restore Box'), 300);
        expect(find.text('Delete permanently'), expected);
        expect(find.text('Restore Box'), findsOneWidget);
        await show(
          SharedAnimalDetailPage(
            api: api,
            id: 1,
            boxes: const [
              {'id': 1, 'status': 'active', 'name': 'Box'},
            ],
            connected: true,
            change: change,
          ),
        );
        await tester.scrollUntilVisible(find.text('Restore Animal'), 300);
        if (role == 'administrator') {
          await tester.scrollUntilVisible(find.text('Delete permanently'), 200);
        }
        expect(find.text('Delete permanently'), expected);
        for (final kind in SharedHistoryKind.values) {
          await show(
            SharedHistoryPage(
              api: api,
              animalId: 1,
              kind: kind,
              active: true,
              change: change,
            ),
          );
          expect(find.byIcon(Icons.delete_outline), expected);
          expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        }
        await show(
          Scaffold(
            body: SingleChildScrollView(
              child: SharedPictureGallery(
                api: api,
                kind: 'boxes',
                recordId: 1,
                active: true,
                change: change,
                onChanged: () {},
              ),
            ),
          ),
        );
        await tester.tap(find.text('Picture gallery'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Delete picture'), expected);
        expect(find.text('Set as primary'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
