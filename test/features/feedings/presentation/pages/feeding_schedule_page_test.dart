import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/feedings/presentation/pages/feeding_schedule_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('schedule keeps its order and scroll position after detail', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final entries = [
      for (var index = 0; index < 30; index++)
        FeedingScheduleEntry(
          animalId: index + 1,
          animalName: 'Animal ${index + 1}',
          dueAt: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FeedingSchedulePage(
          entries: entries.reversed.toList(),
          onSelectAnimal: (id) => navigator.currentState!.push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  Scaffold(appBar: AppBar(), body: Text('Detail $id')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('feeding-schedule-animal-16')),
      100,
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final beforeOffset = scrollable.position.pixels;
    expect(beforeOffset, greaterThan(0));
    final beforeOrder = [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title as Text).data,
    ];

    await tester.tap(
      find.byKey(const Key('feeding-schedule-animal-16')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('Detail 16'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feeding-schedule-page')), findsOneWidget);
    expect(scrollable.position.pixels, closeTo(beforeOffset, 0.1));
    expect([
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title as Text).data,
    ], beforeOrder);
  });

  testWidgets('schedule entry can be activated with the keyboard', (
    tester,
  ) async {
    int? selectedAnimal;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FeedingSchedulePage(
          entries: [
            FeedingScheduleEntry(
              animalId: 7,
              animalName: 'Gizmo',
              dueAt: DateTime.utc(2026, 1, 1),
            ),
          ],
          onSelectAnimal: (id) async => selectedAnimal = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selectedAnimal, 7);
  });
}
