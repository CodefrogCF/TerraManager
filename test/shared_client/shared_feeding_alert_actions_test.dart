import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/feedings/domain/feeding_alert_suppression.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/settings/application/shared_account_settings.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_detail_page.dart';
import 'package:terramanager/shared_client/care_history/presentation/pages/shared_history_page.dart';
import 'package:terramanager/shared_server/settings/application/account_preferences.dart';

const _created = '2026-01-01T00:00:00.000Z';
const _animals = <Map<String, dynamic>>[
  {
    'id': 1,
    'commonName': 'First',
    'latinName': 'Species one',
    'status': 'active',
    'createdAt': _created,
    'tempMin': 20,
    'tempMax': 28,
    'humidityMin': 40,
    'humidityMax': 60,
    'category': 'other',
    'feedingReminderIntervalDays': 1,
    'feedingReminderBaseline': '2020-01-01T00:00:00Z',
  },
  {
    'id': 2,
    'commonName': 'Second',
    'latinName': 'Species two',
    'status': 'active',
    'createdAt': _created,
  },
  {
    'id': 3,
    'commonName': 'Future',
    'latinName': 'Species three',
    'status': 'active',
    'createdAt': _created,
  },
];
const _reminders = <Map<String, dynamic>>[
  {'animalId': 1, 'dueAt': '2020-01-01T00:00:00Z'},
  {'animalId': 2, 'dueAt': '2020-01-02T00:00:00Z'},
  {'animalId': 3, 'dueAt': '2090-01-01T00:00:00Z'},
];

class _Fixture {
  _Fixture({bool big = false, this.onlyDue = false}) {
    preferences = {
      ...defaultAccountPreferences,
      'big_picture_mode_enabled': big,
      'next_feeding_summary_enabled': true,
    };
    api = SharedApiClient(
      Uri.parse('https://test.local'),
      MockClient((request) async {
        http.Response response(Object value, [int status = 200]) =>
            http.Response(jsonEncode(value), status);
        final path = request.url.path;
        if (path.endsWith('/login')) {
          return response({
            'user': {'username': 'alice', 'role': 'caregiver'},
            'csrfToken': 'test',
            'preferences': preferences,
          });
        }
        if (path.endsWith('/preferences')) {
          if (request.method == 'PATCH') {
            if (rejectPreferences) return response({'error': 'failure'}, 500);
            final patch = jsonDecode(request.body) as Map<String, dynamic>;
            if (patch.containsKey(feedingAlertSuppressionsKey)) {
              patch[feedingAlertSuppressionsKey] = {
                ...parseFeedingAlertSuppressions(
                  preferences[feedingAlertSuppressionsKey],
                ),
                ...parseFeedingAlertSuppressions(
                  patch[feedingAlertSuppressionsKey],
                ),
              };
            }
            preferences.addAll(patch);
          }
          return response({'preferences': preferences});
        }
        if (path.endsWith('/animals/1')) {
          return response({'animal': _animals.first});
        }
        if (path.endsWith('/animals/1/feeding-reminder')) {
          return response({
            'reminder': {
              'dueAt': '2020-01-01T00:00:00Z',
              'isDue': true,
              'intervalDays': 1,
              'baseline': '2020-01-01T00:00:00Z',
            },
          });
        }
        if (path.endsWith('/animals/1/feedings')) {
          return response({'feedings': []});
        }
        if (path == '/api/v1/feedings' && request.method == 'POST') {
          expect(jsonDecode(request.body)['animalIds'], [1]);
          writes++;
          return response({
            'feedings': [
              {'id': 1},
            ],
          }, 201);
        }
        if (path.endsWith('/weights')) return response({'weights': []});
        if (path.endsWith('/shedding')) return response({'shedding': []});
        if (path.endsWith('/pictures')) return response({'pictures': []});
        return response({}, 404);
      }),
    );
    settings = SharedAccountSettings(api);
  }
  late final SharedApiClient api;
  late final SharedAccountSettings settings;
  late Map<String, dynamic> preferences;
  bool rejectPreferences = false;
  int writes = 0;
  int reloads = 0;
  final bool onlyDue;
  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await api.login('alice', 'password');
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) => SharedAnimalsPage(
              api: api,
              boxes: const [],
              animals: _animals,
              reminders:
                  (writes == 0 ? _reminders : [_reminders[1], _reminders[2]])
                      .where((entry) => !onlyDue || entry['animalId'] != 3)
                      .toList(),
              connected: true,
              change: (operation) async {
                await operation();
                return true;
              },
              onReload: () async {
                reloads++;
                setState(() {});
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    settings.dispose();
    api.close();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Shared Care keeps schedule accessible when all due alerts are hidden',
    (tester) async {
      final fixture = _Fixture(onlyDue: true);
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      for (final id in [1, 2]) {
        await fixture.settings.suppressFeedingAlertFor24Hours(
          feedingAlertAnimalKey(id, DateTime.parse(_created)),
        );
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('shared-feeding-reminder-summary')),
        findsNothing,
      );
      expect(find.byKey(const Key('shared-animal-due-marker-1')), findsNothing);
      expect(find.byKey(const Key('shared-animal-due-marker-2')), findsNothing);
      await tester.tap(find.byKey(const Key('shared-next-feeding-summary')));
      await tester.pumpAndSettle();
      for (final id in [1, 2]) {
        expect(find.byKey(Key('feeding-schedule-animal-$id')), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    },
  );
  for (final big in [false, true]) {
    for (final fromSummary in [false, true]) {
      testWidgets(
        'Shared Care reminder opens Animal details without writes, big=$big, summary=$fromSummary',
        (tester) async {
          final fixture = _Fixture(big: big);
          fixture.preferences['animal_sort_order'] = 'displayNameAscending';
          addTearDown(fixture.dispose);
          await fixture.pump(tester, locale: Locale(big ? 'de' : 'en'));
          final entry = find.byKey(
            Key(
              fromSummary
                  ? 'shared-feeding-reminder-due-1'
                  : 'shared-animal-due-marker-1',
            ),
          );
          await tester.ensureVisible(entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('feeding-alert-view-animal')));
          await tester.pumpAndSettle();
          final detail = tester.widget<SharedAnimalDetailPage>(
            find.byType(SharedAnimalDetailPage),
          );
          expect(detail.id, 1);
          expect(detail.navigationContext!.recordIds, [1, 3, 2]);
          expect(detail.navigationContext!.currentRecordId, 1);
          expect(fixture.writes, 0);
          expect(
            fixture.settings.isFeedingAlertSuppressed(
              feedingAlertAnimalKey(1, DateTime.parse(_created)),
            ),
            false,
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(SharedAnimalDetailPage), findsNothing);
          expect(entry, findsOneWidget);
          expect(fixture.reloads, greaterThan(0));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      'Shared Care suppression keeps other Animals, schedule and detail, big=$big',
      (tester) async {
        final fixture = _Fixture(big: big);
        addTearDown(fixture.dispose);
        await fixture.pump(tester, locale: Locale(big ? 'de' : 'en'));
        final badge = find.byKey(const Key('shared-animal-due-marker-1'));
        await tester.ensureVisible(badge);
        await tester.tap(badge);
        await tester.pumpAndSettle();
        expect(
          find.text(big ? 'Fütterung hinzufügen' : 'Add Feeding'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('feeding-alert-suppress')));
        await tester.pumpAndSettle();
        expect(badge, findsNothing);
        expect(
          find.byKey(const Key('shared-feeding-reminder-due-1')),
          findsNothing,
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('shared-feeding-reminder-due-2')),
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.byKey(const Key('shared-feeding-reminder-due-2')),
          findsOneWidget,
        );
        expect(
          fixture.settings.isFeedingAlertSuppressed(
            feedingAlertAnimalKey(1, DateTime.parse(_created)),
          ),
          true,
        );
        expect(fixture.writes, 0);
        expect(
          (await SharedPreferences.getInstance()).getString(
            feedingAlertSuppressionsKey,
          ),
          isNull,
        );
        await tester.ensureVisible(
          find.byKey(const Key('shared-next-feeding-summary')),
        );
        await tester.tap(find.byKey(const Key('shared-next-feeding-summary')));
        await tester.pumpAndSettle();
        final scheduled = find.byKey(const Key('feeding-schedule-animal-1'));
        expect(scheduled, findsOneWidget);
        await tester.tap(scheduled);
        await tester.pumpAndSettle();
        expect(find.byType(SharedAnimalDetailPage), findsOneWidget);
        final banner = find.byKey(const Key('shared-feeding-reminder-status'));
        await tester.scrollUntilVisible(banner, 300);
        await tester.pumpAndSettle();
        expect(banner, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
      },
    );
  }

  testWidgets(
    'Shared Care failed suppression remains visible and can be retried',
    (tester) async {
      final fixture = _Fixture()..rejectPreferences = true;
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      final entry = find.byKey(const Key('shared-feeding-reminder-due-1'));
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feeding-alert-suppress')));
      await tester.pumpAndSettle();
      expect(entry, findsOneWidget);
      expect(
        find.text('Could not hide the alert. Please try again.'),
        findsOneWidget,
      );
      fixture.rejectPreferences = false;
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feeding-alert-suppress')));
      await tester.pumpAndSettle();
      expect(entry, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    },
  );

  testWidgets(
    'Shared Care Add Feeding uses existing workflow for selected Animal and refreshes',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.tap(find.byKey(const Key('shared-feeding-reminder-due-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feeding-alert-add-feeding')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SharedHistoryPage>(find.byType(SharedHistoryPage))
            .animalId,
        1,
      );
      expect(find.text('Care entry'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(fixture.writes, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(fixture.reloads, greaterThan(0));
      expect(
        find.byKey(const Key('shared-feeding-reminder-due-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('shared-feeding-reminder-due-2')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    },
  );
}
