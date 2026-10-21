import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/feedings/domain/feeding_alert_suppression.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'suppression persists, expires at exactly 24 hours and separates Animals',
    (tester) async {
      var now = DateTime.utc(2026, 10, 21, 12);
      final key = feedingAlertAnimalKey(1, now);
      final other = feedingAlertAnimalKey(2, now);
      var settings = AppSettingsController(now: () => now);
      await settings.suppressFeedingAlertFor24Hours(key);
      expect(settings.isFeedingAlertSuppressed(key), true);
      expect(settings.isFeedingAlertSuppressed(other), false);
      expect(
        settings.isFeedingAlertSuppressed(
          feedingAlertAnimalKey(1, now.add(const Duration(seconds: 1))),
        ),
        false,
      );
      settings.dispose();

      settings = AppSettingsController(now: () => now);
      addTearDown(settings.dispose);
      await settings.load();
      expect(settings.isFeedingAlertSuppressed(key), true);
      var notifications = 0;
      settings.addListener(() => notifications++);
      now = now.add(
        const Duration(hours: 24) - const Duration(milliseconds: 1),
      );
      await tester.pump(
        const Duration(hours: 24) - const Duration(milliseconds: 1),
      );
      expect(settings.isFeedingAlertSuppressed(key), true);
      now = now.add(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(settings.isFeedingAlertSuppressed(key), false);
      expect(notifications, 1);
    },
  );

  testWidgets(
    'simultaneous local saves retain both Animals and valid settings',
    (tester) async {
      final now = DateTime.now();
      final settings = AppSettingsController();
      addTearDown(settings.dispose);
      final keys = [
        for (var id = 1; id <= 2; id++) feedingAlertAnimalKey(id, now),
      ];
      await Future.wait(keys.map(settings.suppressFeedingAlertFor24Hours));
      final preferences = await SharedPreferences.getInstance();
      final stored = jsonDecode(
        preferences.getString(feedingAlertSuppressionsKey)!,
      );
      expect(stored.keys, unorderedEquals(keys));
      for (final key in keys) {
        expect(settings.isFeedingAlertSuppressed(key), true);
      }
      settings.applyStoredSettings({});
      for (final key in keys) {
        expect(settings.isFeedingAlertSuppressed(key), false);
      }
    },
  );

  testWidgets('malformed optional storage does not prevent startup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      feedingAlertSuppressionsKey: '{broken',
    });
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    await settings.load();
    expect(settings.isFeedingAlertSuppressed('1:0'), false);
    expect(
      parseFeedingAlertSuppressions({'1:0': 'tomorrow', '2:0': -1}),
      isEmpty,
    );
  });
}
