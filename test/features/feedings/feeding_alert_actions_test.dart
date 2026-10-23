import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/feedings/presentation/widgets/feeding_alert_actions.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  for (final language in ['de', 'en']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'reminder actions fit a narrow screen: $language, scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          FeedingAlertAction? result;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => FeedingAlertButton(
                    onPressed: () async {
                      result = await showFeedingAlertActions(
                        context,
                        animalName:
                            'A very long Animal name for a small enclosure',
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // The overview marker is a keyboard-operable button as well as a touch target.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('feeding-alert-actions')),
            findsOneWidget,
          );
          final view = find.byKey(const Key('feeding-alert-view-animal'));
          final add = find.byKey(const Key('feeding-alert-add-feeding'));
          final suppress = find.byKey(const Key('feeding-alert-suppress'));
          expect(
            find.text(language == 'de' ? 'Tier anzeigen' : 'View Animal'),
            findsOneWidget,
          );
          expect(
            tester.getTopLeft(view).dy,
            lessThan(tester.getTopLeft(add).dy),
          );
          expect(
            tester.getTopLeft(add).dy,
            lessThan(tester.getTopLeft(suppress).dy),
          );
          await tester.ensureVisible(view);
          await tester.tap(view);
          await tester.pumpAndSettle();
          expect(result, FeedingAlertAction.viewAnimal);
          expect(find.byKey(const Key('feeding-alert-actions')), findsNothing);
          await tester.tap(find.byType(FeedingAlertButton));
          await tester.pumpAndSettle();
          await tester.ensureVisible(suppress);
          await tester.tap(suppress);
          await tester.pumpAndSettle();
          expect(result, FeedingAlertAction.suppressFor24Hours);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('viewing remains available when write actions are disabled', (
    tester,
  ) async {
    FeedingAlertAction? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FeedingAlertButton(
              onPressed: () async {
                result = await showFeedingAlertActions(
                  context,
                  animalName: 'Animal',
                  enabled: false,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FeedingAlertButton));
    await tester.pumpAndSettle();
    for (final key in ['feeding-alert-add-feeding', 'feeding-alert-suppress']) {
      expect(tester.widget<ListTile>(find.byKey(Key(key))).enabled, false);
    }
    await tester.tap(find.byKey(const Key('feeding-alert-view-animal')));
    await tester.pumpAndSettle();
    expect(result, FeedingAlertAction.viewAnimal);
  });
}
