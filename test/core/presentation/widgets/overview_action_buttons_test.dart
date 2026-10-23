import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/presentation/widgets/overview_action_buttons.dart';

void main() {
  Widget view(Widget body) => MaterialApp(
    home: OverviewScrollScope(
      child: Scaffold(
        body: body,
        floatingActionButton: OverviewActionButtons(
          primary: FloatingActionButton(
            key: const Key('add'),
            heroTag: 'add',
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
          secondary: FloatingActionButton(
            key: const Key('scan'),
            heroTag: 'scan',
            onPressed: () {},
            child: const Icon(Icons.qr_code_scanner),
          ),
        ),
      ),
    ),
  );

  testWidgets('end hides both actions and frees the last context menu', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      view(
        ListView.builder(
          controller: controller,
          padding: const EdgeInsets.only(
            bottom: OverviewActionButtons.bottomPadding,
          ),
          itemCount: 30,
          itemBuilder: (context, index) => ListTile(
            key: Key('row-$index'),
            title: Text('Animal $index'),
            trailing: PopupMenuButton<String>(
              key: Key('menu-$index'),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add')), findsOneWidget);
    expect(find.byKey(const Key('scan')), findsOneWidget);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add')), findsNothing);
    expect(find.byKey(const Key('scan')), findsNothing);
    final listBottom = tester.getBottomLeft(find.byType(ListView)).dy;
    final lastBottom = tester.getBottomLeft(find.byKey(const Key('row-29'))).dy;
    expect(listBottom - lastBottom, closeTo(16, 0.1));
    expect(find.byKey(const Key('menu-29')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu-29')));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent - 50);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add')), findsOneWidget);
    expect(find.byKey(const Key('scan')), findsOneWidget);
  });

  testWidgets('short and empty lists keep their actions available', (
    tester,
  ) async {
    for (final count in [1, 0]) {
      await tester.pumpWidget(
        view(
          ListView.builder(
            itemCount: count,
            itemBuilder: (_, index) => ListTile(title: Text('Animal $index')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add')), findsOneWidget);
      expect(find.byKey(const Key('scan')), findsOneWidget);
    }
  });

  testWidgets('a shorter refreshed collection restores hidden actions', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var count = 30;
    late StateSetter update;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ListView.builder(
              controller: controller,
              itemCount: count,
              itemBuilder: (_, index) => ListTile(title: Text('Animal $index')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add')), findsNothing);
    update(() => count = 1);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add')), findsOneWidget);
    expect(find.byKey(const Key('scan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'replacing a scrolled list with an empty state restores actions',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var empty = false;
      late StateSetter update;
      await tester.pumpWidget(
        view(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return empty
                  ? const OverviewPlaceholder(child: Text('No Animals'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: 30,
                      itemBuilder: (_, index) =>
                          ListTile(title: Text('Animal $index')),
                    );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add')), findsNothing);
      update(() => empty = true);
      await tester.pumpAndSettle();
      expect(find.text('No Animals'), findsOneWidget);
      expect(find.byKey(const Key('add')), findsOneWidget);
      expect(find.byKey(const Key('scan')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
