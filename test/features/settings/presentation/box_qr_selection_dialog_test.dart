import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/settings/presentation/box_qr_selection_dialog.dart';

void main() {
  late AppDatabase database;
  late BoxRepository boxes;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    boxes = BoxRepository(database);
  });

  tearDown(() => database.close());

  Future<Box> createBox(String qrId, {String? name}) async {
    final id = await boxes.createBox(qrId, name: name);
    return (await boxes.getBoxById(id))!;
  }

  Future<void> pumpHost(
    WidgetTester tester, {
    required List<Box> activeBoxes,
    required List<Box> archivedBoxes,
    required ValueChanged<Set<int>?> onClosed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open-selection-dialog'),
              onPressed: () async {
                final result = await showDialog<Set<int>>(
                  context: context,
                  builder: (_) => BoxQrSelectionDialog(
                    activeBoxes: activeBoxes,
                    archivedBoxes: archivedBoxes,
                  ),
                );
                onClosed(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-selection-dialog')));
    await tester.pumpAndSettle();
  }

  CheckboxListTile checkbox(WidgetTester tester, int boxId) {
    return tester.widget<CheckboxListTile>(
      find.byKey(Key('box-qr-selection-checkbox-$boxId')),
    );
  }

  testWidgets('selects all active and archived Boxes initially', (
    tester,
  ) async {
    final named = await createBox(
      'TM:BOX:11111111-1111-4111-8111-111111111111',
      name: 'Main Rack',
    );
    final unnamed = await createBox(
      'TM:BOX:22222222-2222-4222-8222-222222222222',
    );
    final archived = await createBox(
      'TM:BOX:33333333-3333-4333-8333-333333333333',
      name: 'Old Rack',
    );
    await boxes.archiveBox(
      boxId: archived.id,
      reason: BoxArchiveReason.replaced,
      archivedAt: DateTime(2026, 9, 15),
    );
    final archivedRecord = (await boxes.getBoxById(archived.id))!;

    await pumpHost(
      tester,
      activeBoxes: [named, unnamed],
      archivedBoxes: [archivedRecord],
      onClosed: (_) {},
    );

    expect(find.text('Active Boxes'), findsOneWidget);
    expect(find.text('Archived Boxes'), findsOneWidget);
    expect(find.text('Main Rack · Box ${named.id}'), findsOneWidget);
    expect(find.text('Box ${unnamed.id}'), findsOneWidget);
    expect(find.text('Old Rack · Box ${archived.id}'), findsOneWidget);
    expect(checkbox(tester, named.id).value, isTrue);
    expect(checkbox(tester, unnamed.id).value, isTrue);
    expect(checkbox(tester, archived.id).value, isTrue);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('select-all-box-qr-codes-button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'supports individual choice, clear, select all and confirmation',
    (tester) async {
      final first = await createBox(
        'TM:BOX:44444444-4444-4444-8444-444444444444',
      );
      final second = await createBox(
        'TM:BOX:55555555-5555-4555-8555-555555555555',
      );
      Set<int>? result;

      await pumpHost(
        tester,
        activeBoxes: [first, second],
        archivedBoxes: const [],
        onClosed: (value) => result = value,
      );

      await tester.tap(
        find.byKey(Key('box-qr-selection-checkbox-${second.id}')),
      );
      await tester.pumpAndSettle();
      expect(checkbox(tester, first.id).value, isTrue);
      expect(checkbox(tester, second.id).value, isFalse);

      await tester.tap(find.byKey(const Key('clear-box-qr-selection-button')));
      await tester.pumpAndSettle();
      expect(checkbox(tester, first.id).value, isFalse);
      expect(checkbox(tester, second.id).value, isFalse);
      expect(
        find.byKey(const Key('empty-box-qr-selection-error')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('confirm-box-qr-export-button')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('select-all-box-qr-codes-button')));
      await tester.pumpAndSettle();
      expect(checkbox(tester, first.id).value, isTrue);
      expect(checkbox(tester, second.id).value, isTrue);
      expect(
        find.byKey(const Key('empty-box-qr-selection-error')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(Key('box-qr-selection-checkbox-${second.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-box-qr-export-button')));
      await tester.pumpAndSettle();

      expect(result, {first.id});
    },
  );

  testWidgets('cancel returns no selection', (tester) async {
    final box = await createBox('TM:BOX:66666666-6666-4666-8666-666666666666');
    var closed = false;
    Set<int>? result = {box.id};

    await pumpHost(
      tester,
      activeBoxes: [box],
      archivedBoxes: const [],
      onClosed: (value) {
        closed = true;
        result = value;
      },
    );
    await tester.tap(find.byKey(const Key('cancel-box-qr-export-button')));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });
}
