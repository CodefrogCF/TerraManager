import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:terramanager/features/notifications/domain/feeding_notification_target.dart';
import 'package:terramanager/features/notifications/infrastructure/android_local_notification_gateway.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  Map<String, Object?> launch = {'notificationLaunchedApp': false};
  List<Map<String, Object?>> channels = [];
  setUp(() {
    calls.clear();
    launch = {'notificationLaunchedApp': false};
    channels = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'getNotificationAppLaunchDetails' => launch,
            'pendingNotificationRequests' => <Object>[],
            'getNotificationChannels' => channels,
            _ => true,
          };
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'Android initialization never prompts; explicit opt-in requests permission',
    () async {
      final gateway = AndroidLocalNotificationGateway();
      await gateway.initialize((_) {});
      expect(
        calls.map((call) => call.method),
        isNot(contains('requestNotificationsPermission')),
      );
      await gateway.requestPermission();
      expect(
        calls.map((call) => call.method),
        contains('requestNotificationsPermission'),
      );
    },
  );

  test(
    'cold launch forwards its payload without requesting permission',
    () async {
      final target = FeedingNotificationTarget(
        animalId: 8,
        createdAt: DateTime.utc(2026),
        dueAt: DateTime.utc(2026, 11),
      );
      launch = {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationResponseType': 0,
          'payload': target.encode(),
        },
      };
      String? received;
      await AndroidLocalNotificationGateway().initialize(
        (payload) => received = payload,
      );
      expect(received, target.encode());
      expect(
        calls.map((call) => call.method),
        isNot(contains('requestNotificationsPermission')),
      );
    },
  );

  test(
    'a blocked feeding channel is reported even when app permission is granted',
    () async {
      channels = [
        {
          'id': 'feeding_reminders_v1',
          'name': 'Feedings',
          'importance': 0,
          'showBadge': true,
          'bypassDnd': false,
          'playSound': false,
          'enableLights': false,
          'enableVibration': false,
          'ledColor': 0,
          'audioAttributesUsage': 5,
        },
      ];
      final gateway = AndroidLocalNotificationGateway();
      await gateway.initialize((_) {});
      expect(await gateway.isAllowed(), false);
      expect(await gateway.requestPermission(), false);
    },
  );

  for (final language in ['de', 'en']) {
    test(
      'localized $language alarm is generic private one-shot and inexact',
      () async {
        final gateway = AndroidLocalNotificationGateway();
        await gateway.initialize((_) {});
        final due = DateTime.utc(2026, 11, 1, 18);
        await gateway.schedule(
          id: 7,
          at: due,
          languageCode: language,
          target: FeedingNotificationTarget(
            animalId: 42,
            createdAt: DateTime.utc(2026),
            dueAt: due,
          ),
        );
        final args =
            calls
                    .singleWhere((call) => call.method == 'zonedSchedule')
                    .arguments
                as Map;
        expect(args['id'], 7);
        expect(args['title'], 'TerraManager');
        expect(
          args['body'],
          contains(language == 'de' ? 'Fütterung' : 'feeding'),
        );
        expect(args['timeZoneName'], 'Etc/UTC');
        expect(args['matchDateTimeComponents'], isNull);
        expect(args['scheduledDateTime'], startsWith('2026-11-01T18:00:00'));
        final details = args['platformSpecifics'] as Map;
        expect(details['scheduleMode'], 'inexactAllowWhileIdle');
        expect(details['visibility'], 0); // Android VISIBILITY_PRIVATE
        expect(details['enableVibration'], false);
        expect(jsonEncode(args), isNot(contains('Private Animal')));
        expect(
          FeedingNotificationTarget.parse(args['payload'] as String)?.animalId,
          42,
        );
      },
    );
  }

  test(
    'unsupported native platforms do not initialize a notification plugin',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final gateway = AndroidLocalNotificationGateway();
      expect(gateway.isSupported, false);
      await gateway.initialize((_) {});
      expect(calls, isEmpty);
    },
  );

  test('Android manifest restores alarms without network exact-alarm or vibration permission', () {
    final xml = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    );
    const android = 'http://schemas.android.com/apk/res/android';
    const tools = 'http://schemas.android.com/tools';
    final permissions = {
      for (final element in xml.findAllElements('uses-permission'))
        if (element.getAttribute('node', namespaceUri: tools) != 'remove')
          element.getAttribute('name', namespaceUri: android),
    };
    expect(
      permissions,
      containsAll([
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      ]),
    );
    expect(
      permissions.intersection({
        'android.permission.INTERNET',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.USE_EXACT_ALARM',
        'android.permission.VIBRATE',
      }),
      isEmpty,
    );
    final receivers = xml.findAllElements('receiver').toList();
    expect(receivers, hasLength(2));
    expect(
      receivers.every(
        (item) =>
            item.getAttribute('exported', namespaceUri: android) == 'false',
      ),
      true,
    );
    expect(xml.toXmlString(), contains('android.intent.action.BOOT_COMPLETED'));
    expect(
      xml.toXmlString(),
      contains('android.intent.action.MY_PACKAGE_REPLACED'),
    );
  });
}
