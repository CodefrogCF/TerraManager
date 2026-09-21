import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_history_page.dart';
import 'package:terramanager/features/navigation/domain/detail_navigation_context.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/archive_sort_order.dart';

void main() {
  late AppDatabase database;
  late BoxRepository repository;

  var qrCounter = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    database = AppDatabase.test(NativeDatabase.memory());

    repository = BoxRepository(database);

    qrCounter = 0;
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> createArchivedBox({
    String? name,
    required BoxArchiveReason reason,
    required DateTime archivedAt,
  }) async {
    qrCounter++;

    final id = await repository.createBox('history-box-$qrCounter', name: name);

    final archived = await repository.archiveBox(
      boxId: id,
      reason: reason,
      archivedAt: archivedAt,
    );

    expect(archived, isTrue);

    return id;
  }

  Future<AppSettingsController> pumpHistory(WidgetTester tester) async {
    final settings = AppSettingsController();

    await settings.load();

    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(home: BoxHistoryPage(database: database)),
      ),
    );

    await tester.pumpAndSettle();

    return settings;
  }

  testWidgets('shows empty archived Box state', (tester) async {
    final settings = await pumpHistory(tester);

    expect(find.byKey(const Key('box-history-empty-state')), findsOneWidget);

    expect(find.text('No archived Boxes'), findsOneWidget);

    settings.dispose();
  });

  testWidgets('shows archive reason and date', (tester) async {
    final id = await createArchivedBox(
      name: 'Old enclosure',
      reason: BoxArchiveReason.replaced,
      archivedAt: DateTime(2026, 9, 2),
    );

    final settings = await pumpHistory(tester);

    expect(find.text('Old enclosure'), findsOneWidget);

    expect(find.text('Box $id'), findsOneWidget);

    expect(find.text('Replaced • 02.09.2026'), findsOneWidget);

    settings.dispose();
  });

  testWidgets('defaults to newest archived first '
      'and passes visible order to detail', (tester) async {
    final oldestId = await createArchivedBox(
      name: 'Oldest',
      reason: BoxArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );

    final middleId = await createArchivedBox(
      name: 'Middle',
      reason: BoxArchiveReason.other,
      archivedAt: DateTime(2026, 9, 2),
    );

    final newestId = await createArchivedBox(
      name: 'Newest',
      reason: BoxArchiveReason.other,
      archivedAt: DateTime(2026, 9, 3),
    );

    final settings = await pumpHistory(tester);

    expect(settings.boxArchiveSortOrder, ArchiveSortOrder.archivedNewestFirst);

    expect(
      tester
          .getTopLeft(
            find.byKey(
              Key(
                'archived-box-list-item-'
                '$newestId',
              ),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                Key(
                  'archived-box-list-item-'
                  '$middleId',
                ),
              ),
            )
            .dy,
      ),
    );

    await tester.tap(
      find.byKey(
        Key(
          'archived-box-list-item-'
          '$middleId',
        ),
      ),
    );

    await tester.pumpAndSettle();

    final detail = tester.widget<BoxDetailPage>(find.byType(BoxDetailPage));

    expect(detail.navigationContext!.source, DetailNavigationSource.boxes);

    expect(detail.navigationContext!.recordIds, [newestId, middleId, oldestId]);

    settings.dispose();
  });

  testWidgets('archived Box context menu exposes Restore and Duplicate', (
    tester,
  ) async {
    final id = await createArchivedBox(
      name: 'Menu Box',
      reason: BoxArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );

    final settings = await pumpHistory(tester);

    await tester.tap(find.byKey(Key('archived-box-context-menu-button-$id')));

    await tester.pumpAndSettle();

    expect(find.byKey(Key('archived-box-restore-action-$id')), findsOneWidget);

    expect(
      find.byKey(Key('archived-box-duplicate-action-$id')),
      findsOneWidget,
    );

    expect(find.text('Restore Box'), findsOneWidget);
    expect(find.text('Duplicate Box'), findsOneWidget);

    settings.dispose();
  });

  testWidgets('restores Box directly from archive context menu', (
    tester,
  ) async {
    final id = await createArchivedBox(
      name: 'Restore Box',
      reason: BoxArchiveReason.replaced,
      archivedAt: DateTime(2026, 9, 1),
    );

    final settings = await pumpHistory(tester);

    await tester.tap(find.byKey(Key('archived-box-context-menu-button-$id')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('archived-box-restore-action-$id')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('restore-box-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-restore-box-button')));

    await tester.pumpAndSettle();

    final box = await repository.getBoxById(id);

    expect(box, isNotNull);
    expect(box!.archiveReason, isNull);
    expect(box.archivedAt, isNull);
    expect(box.archiveNotes, isNull);

    expect(find.byKey(Key('archived-box-list-item-$id')), findsNothing);

    expect(find.byKey(const Key('box-history-empty-state')), findsOneWidget);

    expect(find.text('Box restored'), findsOneWidget);

    settings.dispose();
  });

  testWidgets('sorts archived Boxes alphabetically '
      'ascending and descending', (tester) async {
    final tenId = await createArchivedBox(
      name: 'Terrarium 10',
      reason: BoxArchiveReason.other,
      archivedAt: DateTime(2026, 9, 1),
    );

    final twoId = await createArchivedBox(
      name: 'Terrarium 2',
      reason: BoxArchiveReason.other,
      archivedAt: DateTime(2026, 9, 2),
    );

    final alphaId = await createArchivedBox(
      name: 'Alpha',
      reason: BoxArchiveReason.other,
      archivedAt: DateTime(2026, 9, 3),
    );

    final settings = await pumpHistory(tester);

    await tester.tap(find.byKey(const Key('box-archive-sort-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('box-archive-sort-option-name')));

    await tester.pumpAndSettle();

    expect(settings.boxArchiveSortOrder, ArchiveSortOrder.nameAscending);

    expect(
      tester
          .getTopLeft(
            find.byKey(
              Key(
                'archived-box-list-item-'
                '$alphaId',
              ),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                Key(
                  'archived-box-list-item-'
                  '$twoId',
                ),
              ),
            )
            .dy,
      ),
    );

    expect(
      tester
          .getTopLeft(
            find.byKey(
              Key(
                'archived-box-list-item-'
                '$twoId',
              ),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                Key(
                  'archived-box-list-item-'
                  '$tenId',
                ),
              ),
            )
            .dy,
      ),
    );

    var preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('box_archive_sort_order'), 'nameAscending');

    await tester.tap(find.byKey(const Key('box-archive-sort-button')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('box-archive-sort-option-name')));

    await tester.pumpAndSettle();

    expect(settings.boxArchiveSortOrder, ArchiveSortOrder.nameDescending);

    expect(
      tester
          .getTopLeft(
            find.byKey(
              Key(
                'archived-box-list-item-'
                '$tenId',
              ),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                Key(
                  'archived-box-list-item-'
                  '$twoId',
                ),
              ),
            )
            .dy,
      ),
    );

    preferences = await SharedPreferences.getInstance();

    expect(preferences.getString('box_archive_sort_order'), 'nameDescending');

    settings.dispose();
  });
}
