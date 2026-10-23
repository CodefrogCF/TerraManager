import 'package:flutter/material.dart';

import '../../../l10n/app_localizations_context.dart';
import '../application/feeding_notification_controller.dart';

class LocalNotificationsScope extends InheritedWidget {
  const LocalNotificationsScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final FeedingNotificationController controller;

  static FeedingNotificationController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LocalNotificationsScope>()
      ?.controller;

  @override
  bool updateShouldNotify(LocalNotificationsScope oldWidget) =>
      controller != oldWidget.controller;
}

class LocalNotificationsSettings extends StatelessWidget {
  const LocalNotificationsSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LocalNotificationsScope.maybeOf(context);
    if (controller == null || !controller.isSupported) {
      return const SizedBox.shrink();
    }
    final text = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.localNotificationsHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SwitchListTile(
              key: const Key('local-notifications-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(text.localNotificationsEnable),
              subtitle: Text(text.localNotificationsDescription),
              value: controller.enabled,
              onChanged: controller.busy ? null : controller.setEnabled,
            ),
            Text(
              text.localNotificationsTiming,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (controller.permissionBlocked) ...[
              const SizedBox(height: 8),
              Text(text.localNotificationsDenied),
            ],
            if (controller.failed) ...[
              const SizedBox(height: 8),
              Text(
                text.localNotificationsFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: controller.busy ? null : controller.refresh,
                child: Text(text.localNotificationsRetry),
              ),
            ],
            if (controller.enabled || controller.permissionBlocked)
              TextButton.icon(
                onPressed: controller.busy ? null : controller.openSettings,
                icon: const Icon(Icons.settings_outlined),
                label: Text(text.localNotificationsAndroidSettings),
              ),
          ],
        ),
      ),
    );
  }
}
