import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/animal_name_order.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart';
import 'package:terramanager/shared_client/feedings/presentation/pages/shared_feeding_reminder_page.dart';
import 'package:terramanager/shared_client/feedings/presentation/widgets/shared_feeding_information.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_form.dart';

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
  const timeZoneChannel = MethodChannel('com.codefrog.terramanager/browser');
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timeZoneChannel, null);
  });

  void setDeviceTimeZone(String? zone) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timeZoneChannel, (call) async {
          expect(call.method, 'deviceTimeZoneId');
          return zone;
        });
  }

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
    await settings.setNextFeedingSummaryEnabled(true);
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
    await tester.tap(find.byKey(const Key('shared-next-feeding-summary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feeding-schedule-page')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Due')).dy,
      lessThan(tester.getTopLeft(find.text('Next')).dy),
    );
  });

  testWidgets(
    'next feeding preference controls list and grid without hiding due reminders',
    (tester) async {
      final settings = AppSettingsController();
      final api = SharedApiClient(
        Uri.parse('https://192.168.1.117'),
        MockClient((_) async => http.Response('{}', 404)),
      );
      addTearDown(settings.dispose);
      addTearDown(api.close);
      final now = DateTime.now();
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SharedAnimalsPage(
              api: api,
              boxes: const [],
              animals: [
                {..._animal, 'id': 1, 'commonName': 'Due'},
                {..._animal, 'id': 2, 'commonName': 'Upcoming'},
              ],
              reminders: [
                {
                  'animalId': 1,
                  'dueAt': now
                      .subtract(const Duration(days: 1))
                      .toIso8601String(),
                },
                {
                  'animalId': 2,
                  'dueAt': now.add(const Duration(days: 1)).toIso8601String(),
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
      final next = find.byKey(const Key('shared-next-feeding-summary'));
      final due = find.byKey(const Key('shared-feeding-reminder-summary'));
      for (final bigPicture in [false, true]) {
        await settings.setBigPictureModeEnabled(bigPicture);
        await settings.setNextFeedingSummaryEnabled(false);
        await tester.pumpAndSettle();
        expect(next, findsNothing);
        expect(due, findsOneWidget);
        await settings.setNextFeedingSummaryEnabled(true);
        await tester.pumpAndSettle();
        expect(next, findsOneWidget);
        expect(due, findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('animal-history-button')));
      await tester.pumpAndSettle();
      expect(next, findsNothing);
      expect(due, findsNothing);
      final restoredSettings = AppSettingsController();
      await restoredSettings.load();
      expect(restoredSettings.nextFeedingSummaryEnabled, isTrue);
      restoredSettings.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overview and schedule show the saved Berlin time zone', (
    tester,
  ) async {
    final settings = AppSettingsController();
    await settings.setNextFeedingSummaryEnabled(true);
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((_) async => http.Response('{}', 404)),
    );
    addTearDown(settings.dispose);
    addTearDown(api.close);
    final animals = [
      {..._animal, 'id': 7, 'feedingReminderTimeZone': 'Europe/Berlin'},
      {..._animal, 'id': 8, 'feedingReminderTimeZone': 'Europe/Berlin'},
    ];
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SharedAnimalsPage(
            api: api,
            boxes: const [],
            animals: animals,
            reminders: const [
              {'animalId': 7, 'dueAt': '2026-06-01T16:00:00Z'},
              {'animalId': 8, 'dueAt': '2027-06-07T16:00:00Z'},
            ],
            connected: true,
            change: (_) async => true,
            onReload: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dueTile = tester.widget<ListTile>(
      find.byKey(const Key('shared-feeding-reminder-due-7')),
    );
    expect((dueTile.subtitle as Text).data, contains('18:00 (Europe/Berlin)'));
    final nextTile = tester.widget<ListTile>(
      find.descendant(
        of: find.byKey(const Key('shared-next-feeding-summary')),
        matching: find.byType(ListTile),
      ),
    );
    expect((nextTile.subtitle as Text).data, contains('18:00 (Europe/Berlin)'));

    await tester.tap(find.byKey(const Key('shared-next-feeding-summary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feeding-schedule-page')), findsOneWidget);
    for (final id in [7, 8]) {
      final scheduleTile = tester.widget<ListTile>(
        find.byKey(Key('feeding-schedule-animal-$id')),
      );
      expect(
        (scheduleTile.subtitle as Text).data,
        contains('18:00 (Europe/Berlin)'),
      );
    }
  });

  testWidgets('Animal detail shows the saved Berlin due time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SharedFeedingInformation(
            entries: Future.value(const []),
            animal: const {
              ..._animal,
              'feedingReminderBaseline': '2026-05-31T12:00:00Z',
              'feedingReminderWeekdays': 1,
              'feedingReminderMinuteOfDay': 1080,
              'feedingReminderTimeZone': 'Europe/Berlin',
            },
            due: true,
            onRetry: () {},
            onHistory: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dueTile = tester.widget<ListTile>(
      find.descendant(
        of: find.byKey(const Key('shared-feeding-reminder-status')),
        matching: find.byType(ListTile),
      ),
    );
    expect((dueTile.subtitle as Text).data, contains('18:00 (Europe/Berlin)'));
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
    expect(body.keys, {
      'expectedRevision',
      'intervalDays',
      'baseline',
      'weekdays',
      'minuteOfDay',
      'timeZone',
    });
    expect(body['weekdays'], isNull);
  });

  testWidgets('shared reminder settings send weekday plan fields', (
    tester,
  ) async {
    setDeviceTimeZone('Europe/Berlin');
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
    await tester.tap(find.text('Selected weekdays'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('feeding-weekday-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('feeding-weekday-3')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('shared-feeding-reminder-save')),
    );
    await tester.tap(find.byKey(const Key('shared-feeding-reminder-save')));
    await tester.pump();
    expect(saved, isNotNull);
    final body = jsonDecode(saved!.body) as Map<String, dynamic>;
    expect(body['intervalDays'], isNull);
    expect(body['weekdays'], 1 | 4);
    expect(body['minuteOfDay'], 720);
    expect(body['timeZone'], 'Europe/Berlin');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shared reminder edits retain an existing schedule zone', (
    tester,
  ) async {
    setDeviceTimeZone('America/New_York');
    http.Request? saved;
    final existing = {
      ..._animal,
      'feedingReminderBaseline': '2026-10-04T12:00:00Z',
      'feedingReminderWeekdays': 1,
      'feedingReminderMinuteOfDay': 1080,
      'feedingReminderTimeZone': 'Europe/Berlin',
    };
    final api = await _client((request) async {
      if (request.url.path == '/api/v1/animals/7' && request.method == 'GET') {
        return http.Response(jsonEncode({'animal': existing}), 200);
      }
      if (request.url.path == '/api/v1/animals/7/feeding-reminder') {
        saved = request;
        return http.Response(jsonEncode({'animal': existing}), 200);
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
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('feeding-reminder-time-zone')), findsNothing);
    expect(find.byKey(const Key('feeding-reminder-time')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('shared-feeding-reminder-save-action')),
    );
    await tester.pump();

    expect(saved, isNotNull);
    final body = jsonDecode(saved!.body) as Map<String, dynamic>;
    expect(body['minuteOfDay'], 1080);
    expect(body['timeZone'], 'Europe/Berlin');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shared reminder rejects a missing device time zone', (
    tester,
  ) async {
    setDeviceTimeZone(null);
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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('feeding-reminder-enabled-switch')));
    await tester.pump();
    await tester.tap(find.text('Selected weekdays'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('feeding-weekday-1')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('shared-feeding-reminder-save')),
    );
    await tester.tap(find.byKey(const Key('shared-feeding-reminder-save')));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(saved, isNull);
    expect(
      find.byKey(const Key('shared-feeding-reminder-error')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Could not determine the device time zone'),
      findsWidgets,
    );
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

  testWidgets('new shared Animal stores a detected weekday zone', (
    tester,
  ) async {
    setDeviceTimeZone('Europe/Berlin');
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
    await tester.tap(find.text('Selected weekdays'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('feeding-weekday-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feeding-weekday-1')));
    await tester.pump();
    expect(find.byKey(const Key('feeding-reminder-time-zone')), findsNothing);
    await tester.dragUntilVisible(
      find.byKey(const Key('shared-save-animal')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.byKey(const Key('shared-save-animal')));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(created, isNotNull);
    final body = jsonDecode(created!.body) as Map<String, dynamic>;
    expect(body['feedingReminderWeekdays'], 1);
    expect(body['feedingReminderMinuteOfDay'], 720);
    expect(body['feedingReminderTimeZone'], 'Europe/Berlin');
  });

  testWidgets('editing a shared Animal preserves its weekday time and zone', (
    tester,
  ) async {
    setDeviceTimeZone('America/New_York');
    http.Request? saved;
    final existing = {
      ..._animal,
      'feedingReminderBaseline': '2026-10-04T12:00:00Z',
      'feedingReminderWeekdays': 1,
      'feedingReminderMinuteOfDay': 1080,
      'feedingReminderTimeZone': 'Europe/Berlin',
    };
    final api = await _client((request) async {
      if (request.url.path == '/api/v1/animals/7' && request.method == 'PUT') {
        saved = request;
        return http.Response(jsonEncode({'animal': existing}), 200);
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
          initial: existing,
          change: (operation) async {
            await operation();
            return true;
          },
        ),
      ),
    );
    await tester.dragUntilVisible(
      find.byKey(const Key('shared-save-animal')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.byKey(const Key('shared-save-animal')));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(saved, isNotNull);
    final body = jsonDecode(saved!.body) as Map<String, dynamic>;
    expect(body['feedingReminderWeekdays'], 1);
    expect(body['feedingReminderMinuteOfDay'], 1080);
    expect(body['feedingReminderTimeZone'], 'Europe/Berlin');
  });
}
