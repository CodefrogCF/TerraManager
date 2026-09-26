import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_collection_pages.dart';
import 'package:terramanager/shared_client/shared_feeding_reminder_page.dart';
import 'package:terramanager/shared_client/shared_forms.dart';

const _animal = {
  'id': 7,
  'status': 'active',
  'revision': 'opened-revision',
  'boxId': 1,
  'commonName': 'Gizmo',
  'latinName': 'Example species',
  'category': 'reptile',
  'tempMin': 22,
  'tempMax': 28,
  'humidityMin': 40,
  'humidityMax': 60,
};

Future<SharedApiClient> _client(
  Future<http.Response> Function(http.Request) handle,
) async {
  final api = SharedApiClient(
    Uri.parse('https://192.168.1.117'),
    MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'user': {'username': 'hagen', 'role': 'caregiver'},
            'csrfToken': 'test-token',
          }),
          200,
        );
      }
      return handle(request);
    }),
  );
  await api.login('hagen', 'password');
  return api;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'reminder expansion survives scrolling and overview view changes',
    (tester) async {
      final settings = AppSettingsController();
      final api = SharedApiClient(
        Uri.parse('https://192.168.1.117'),
        MockClient((_) async => http.Response('{}', 404)),
      );
      addTearDown(settings.dispose);
      addTearDown(api.close);
      final animals = [
        for (var id = 1; id <= 30; id++)
          {
            ..._animal,
            'id': id,
            'commonName': 'Animal $id',
            'latinName': 'Species $id',
          },
      ];
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: SharedAnimalsPage(
              api: api,
              boxes: const [],
              animals: animals,
              reminders: [
                {'animalId': 1, 'dueAt': '2020-01-01T12:00:00Z'},
              ],
              connected: true,
              change: (_) async => true,
              onReload: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feeding reminders'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      await settings.setBigPictureModeEnabled(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await settings.setBigPictureModeEnabled(false);
      await settings.setAnimalNameOrder(AnimalNameOrder.latinNameFirst);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scrollable = find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('1 Animal is due for feeding'), findsOneWidget);
      expect(
        find.byKey(const Key('shared-feeding-reminder-due-1')).hitTestable(),
        findsNothing,
      );
      await tester.tap(find.text('Feeding reminders'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('shared-feeding-reminder-due-1')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Species 1'), findsWidgets);
    },
  );

  testWidgets('shared overview shows due and next server reminders', (
    tester,
  ) async {
    final settings = AppSettingsController();
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((_) async => http.Response('{}', 404)),
    );
    addTearDown(settings.dispose);
    addTearDown(api.close);
    final now = DateTime.now().toUtc();
    final animals = [
      {..._animal, 'id': 7, 'commonName': 'Due'},
      {..._animal, 'id': 8, 'commonName': 'Next'},
    ];
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SharedAnimalsPage(
            api: api,
            boxes: const [
              {'id': 1, 'name': 'Box', 'status': 'active'},
            ],
            animals: animals,
            reminders: [
              {
                'animalId': 7,
                'dueAt': now
                    .subtract(const Duration(days: 1))
                    .toIso8601String(),
              },
              {
                'animalId': 8,
                'dueAt': now.add(const Duration(days: 2)).toIso8601String(),
              },
            ],
            connected: true,
            change: (_) async => true,
            onReload: () async {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('shared-feeding-reminder-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-feeding-reminder-due-7')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shared-next-feeding-summary')),
      findsOneWidget,
    );
    final group = find.byKey(
      const PageStorageKey<String>('shared-feeding-reminder-summary-toggle'),
    );
    expect(group, findsOneWidget);
    await tester.tap(find.text('Feeding reminders'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('shared-feeding-reminder-due-7')).hitTestable(),
      findsNothing,
    );
    expect(find.text('1 Animal is due for feeding'), findsOneWidget);
    await tester.tap(find.text('Feeding reminders'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('shared-feeding-reminder-due-7')),
      findsOneWidget,
    );
  });

  testWidgets('reminder settings save only the reminder with a revision', (
    tester,
  ) async {
    http.Request? saved;
    final api = await _client((request) async {
      if (request.url.path == '/api/v1/animals/7' && request.method == 'GET') {
        return http.Response(jsonEncode({'animal': _animal}), 200);
      }
      if (request.url.path == '/api/v1/animals/7/feeding-reminder') {
        saved = request;
        return http.Response(jsonEncode({'animal': _animal}), 200);
      }
      return http.Response('{}', 404);
    });
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: SharedFeedingReminderPage(
          api: api,
          animalId: 7,
          change: (operation) async {
            await operation();
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('feeding-reminder-enabled-switch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('feeding-reminder-interval-days-field')),
      '4',
    );
    await tester.tap(find.byKey(const Key('shared-feeding-reminder-save')));
    await tester.pump();
    expect(saved, isNotNull);
    final body = jsonDecode(saved!.body) as Map<String, dynamic>;
    expect(body['expectedRevision'], 'opened-revision');
    expect(body['intervalDays'], 4);
    expect(DateTime.tryParse(body['baseline'] as String), isNotNull);
    expect(body.keys, {'expectedRevision', 'intervalDays', 'baseline'});
  });

  testWidgets('new Animal can enable a reminder with a baseline', (
    tester,
  ) async {
    http.Request? created;
    final api = await _client((request) async {
      if (request.url.path == '/api/v1/animals' && request.method == 'POST') {
        created = request;
        return http.Response(jsonEncode({'animal': _animal}), 201);
      }
      return http.Response('{}', 404);
    });
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: SharedAnimalForm(
          api: api,
          boxes: const [
            {'id': 1, 'name': 'Box', 'status': 'active'},
          ],
          change: (operation) async {
            await operation();
            return true;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Gizmo');
    await tester.enterText(find.byType(TextFormField).at(1), 'Example species');
    await tester.dragUntilVisible(
      find.text('Additional characteristics'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.text('Additional characteristics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Additional characteristics'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('feeding-reminder-enabled-switch')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(
      find.byKey(const Key('feeding-reminder-enabled-switch')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feeding-reminder-enabled-switch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('feeding-reminder-interval-days-field')),
      '5',
    );
    await tester.dragUntilVisible(
      find.byKey(const Key('shared-save-animal')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.byKey(const Key('shared-save-animal')));
    await tester.pump();
    expect(created, isNotNull);
    final body = jsonDecode(created!.body) as Map<String, dynamic>;
    expect(body['feedingReminderIntervalDays'], 5);
    expect(
      DateTime.tryParse(body['feedingReminderBaseline'] as String),
      isNotNull,
    );
  });
}
