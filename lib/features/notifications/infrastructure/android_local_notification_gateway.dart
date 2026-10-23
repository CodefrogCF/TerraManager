import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/generated/app_localizations_de.dart';
import '../../../l10n/generated/app_localizations_en.dart';
import '../application/local_notification_gateway.dart';
import '../domain/feeding_notification_target.dart';

class AndroidLocalNotificationGateway implements LocalNotificationGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  AndroidFlutterLocalNotificationsPlugin get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()!;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> initialize(void Function(String?) onTap) async {
    if (!isSupported) return;
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_feeding_notification'),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
    if (initialized != true) {
      throw StateError('Android notification initialization failed');
    }
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      onTap(launch?.notificationResponse?.payload);
    }
  }

  @override
  Future<bool> isAllowed() async {
    if (!(await _android.areNotificationsEnabled() ?? false)) return false;
    final channels = await _android.getNotificationChannels() ?? [];
    return !channels.any(
      (channel) =>
          channel.id == 'feeding_reminders_v1' &&
          channel.importance == Importance.none,
    );
  }

  @override
  Future<bool> requestPermission() async =>
      (await _android.requestNotificationsPermission() ?? false) &&
      await isAllowed();

  @override
  Future<void> openSettings() async {
    await _android.openAppNotificationSettings();
  }

  @override
  Future<Set<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests())
          .map((item) => item.id)
          .toSet();

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String languageCode,
    required FeedingNotificationTarget target,
  }) async {
    final AppLocalizations text = languageCode == 'de'
        ? AppLocalizationsDe()
        : AppLocalizationsEn();
    await _android.createNotificationChannel(
      AndroidNotificationChannel(
        'feeding_reminders_v1',
        text.localNotificationsChannel,
        description: text.localNotificationsChannelDescription,
        importance: Importance.defaultImportance,
        enableVibration: false,
      ),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: 'TerraManager',
      body: text.localNotificationsBody,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: AndroidNotificationDetails(
        'feeding_reminders_v1',
        text.localNotificationsChannel,
        channelDescription: text.localNotificationsChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        visibility: NotificationVisibility.private,
        enableVibration: false,
        icon: 'ic_feeding_notification',
        autoCancel: true,
      ).asNotificationDetails(),
      payload: target.encode(),
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

extension on AndroidNotificationDetails {
  NotificationDetails asNotificationDetails() =>
      NotificationDetails(android: this);
}
