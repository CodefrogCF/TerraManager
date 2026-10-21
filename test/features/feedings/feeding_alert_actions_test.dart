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
          final suppress = find.byKey(const Key('feeding-alert-suppress'));
          await tester.ensureVisible(suppress);
          await tester.tap(suppress);
          await tester.pumpAndSettle();
          expect(result, FeedingAlertAction.suppressFor24Hours);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
