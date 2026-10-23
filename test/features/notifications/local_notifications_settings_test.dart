import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/notifications/application/feeding_notification_controller.dart';
import 'package:terramanager/features/notifications/presentation/local_notifications_settings.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

import 'feeding_notification_controller_test.dart'
    show FakeNotificationGateway, MemoryNotificationStore;

void main() {
  for (final language in ['de', 'en']) {
    testWidgets(
      '$language explicit opt-in and denial stay readable at narrow width and large text',
      (tester) async {
        final database = AppDatabase.test(NativeDatabase.memory());
        final gateway = FakeNotificationGateway()..allowed = false;
        final controller = FeedingNotificationController(
          database: database,
          gateway: gateway,
          store: MemoryNotificationStore(),
        );
        addTearDown(() async {
          controller.dispose();
          await database.close();
        });
        await controller.start();
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          LocalNotificationsScope(
            controller: controller,
            child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.6)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: LocalNotificationsSettings(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(gateway.permissionRequests, 0);
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const Key('local-notifications-switch')),
              )
              .value,
          false,
        );
        await tester.tap(find.byKey(const Key('local-notifications-switch')));
        await tester.pumpAndSettle();
        expect(gateway.permissionRequests, 1);
        expect(controller.enabled, false);
        expect(
          find.textContaining(
            language == 'de' ? 'sind gesperrt' : 'are blocked',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('unsupported platforms hide the Android setting', (tester) async {
    final database = AppDatabase.test(NativeDatabase.memory());
    final controller = FeedingNotificationController(
      database: database,
      gateway: FakeNotificationGateway()..supported = false,
      store: MemoryNotificationStore(),
    );
    addTearDown(() async {
      controller.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      LocalNotificationsScope(
        controller: controller,
        child: const MaterialApp(
          home: Scaffold(body: LocalNotificationsSettings()),
        ),
      ),
    );
    expect(find.byType(SwitchListTile), findsNothing);
  });
}
