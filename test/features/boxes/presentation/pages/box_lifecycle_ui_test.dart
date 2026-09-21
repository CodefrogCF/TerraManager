import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/enums/box_archive_reason.dart';
import 'package:terramanager/core/database/enums/box_status.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_edit_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/boxes_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase database;
  late BoxRepository boxes;
  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    boxes = BoxRepository(database);
  });
  tearDown(() => database.close());

  Future<int> createAnimal(int boxId, String name) =>
      AnimalRepository(database).createAnimal(
        boxId: boxId,
        commonName: name,
        latinName: '$name species',
        tempMin: 20,
        tempMax: 30,
        humidityMin: 40,
        humidityMax: 60,
      );

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: page,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openArchiveDialog(WidgetTester tester) async {
    await scrollTo(tester, 'archive-box-button');
    await tester.tap(find.byKey(const Key('archive-box-button')));
    await tester.pumpAndSettle();
  }

  Future<void> selectReason(
    WidgetTester tester, {
    String label = 'Sold',
  }) async {
    await tester.tap(find.byKey(const Key('box-archive-reason-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'occupied Box explains which Animals must move and preserves them',
    (tester) async {
      final id = await boxes.createBoxWithGeneratedQrId();
      await createAnimal(id, 'First Animal');
      await createAnimal(id, 'Second Animal');
      final before = (await AnimalRepository(
        database,
      ).getAllAnimals()).map((animal) => animal.toJson()).toList();
      await pumpPage(tester, BoxEditPage(database: database, boxId: id));
      await openArchiveDialog(tester);
      expect(
        find.byKey(const Key('cannot-archive-box-dialog')),
        findsOneWidget,
      );
      expect(find.text('First Animal'), findsOneWidget);
      expect(find.text('Second Animal'), findsOneWidget);
      expect(find.textContaining('another active Box'), findsOneWidget);
      expect(find.byKey(const Key('confirm-archive-box-button')), findsNothing);
      expect((await boxes.getBoxById(id))!.status, BoxStatus.active);
      expect(
        (await AnimalRepository(
          database,
        ).getAllAnimals()).map((animal) => animal.toJson()),
        before,
      );
    },
  );

  testWidgets('reason is required and cancel leaves Box and draft unchanged', (
    tester,
  ) async {
    final id = await boxes.createBoxWithGeneratedQrId(notes: 'Saved notes');
    await pumpPage(tester, BoxEditPage(database: database, boxId: id));
    await scrollTo(tester, 'box-notes-field');
    await tester.enterText(
      find.byKey(const Key('box-notes-field')),
      'Draft notes',
    );
    await openArchiveDialog(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-archive-box-button')),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('Unsaved changes in Edit Box'), findsOneWidget);
    await selectReason(tester);
    await tester.tap(find.byKey(const Key('cancel-archive-box-button')));
    await tester.pumpAndSettle();
    expect((await boxes.getBoxById(id))!.status, BoxStatus.active);
    expect((await boxes.getBoxById(id))!.notes, 'Saved notes');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('box-notes-field')))
          .controller!
          .text,
      'Draft notes',
    );
  });

  testWidgets('archiving the swiped Box returns to the active overview', (
    tester,
  ) async {
    final first = await boxes.createBoxWithGeneratedQrId();
    final second = await boxes.createBoxWithGeneratedQrId(
      notes: 'Original notes',
    );
    final qr = (await boxes.getBoxById(second))!.qrId;
    await pumpPage(tester, BoxesPage(database: database));
    await tester.tap(find.byKey(Key('box-list-item-$first')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('box-detail-swipe-area')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('box-detail-title'))).data,
      'Box $second',
    );
    await tester.tap(find.byKey(const Key('edit-box-button')));
    await tester.pumpAndSettle();
    await openArchiveDialog(tester);
    await selectReason(tester);
    await tester.enterText(
      find.byKey(const Key('box-archive-notes-field')),
      '  New owner  ',
    );
    final confirm = tester
        .widget<FilledButton>(
          find.byKey(const Key('confirm-archive-box-button')),
        )
        .onPressed!;
    confirm();
    confirm();
    await tester.pumpAndSettle();
    expect(find.byType(BoxEditPage), findsNothing);
    expect(find.byType(BoxDetailPage), findsNothing);
    expect(find.byKey(Key('box-list-item-$first')), findsOneWidget);
    expect(find.byKey(Key('box-list-item-$second')), findsNothing);
    final archived = (await boxes.getBoxById(second))!;
    expect(archived.status, BoxStatus.archived);
    expect(archived.qrId, qr);
    expect(archived.notes, 'Original notes');
    expect(archived.archiveNotes, 'New owner');
    expect(archived.archiveReason, BoxArchiveReason.sold);
    expect(archived.archivedAt, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newly assigned Animal blocks archive at confirmation', (
    tester,
  ) async {
    final id = await boxes.createBoxWithGeneratedQrId();
    await pumpPage(tester, BoxEditPage(database: database, boxId: id));
    await openArchiveDialog(tester);
    await selectReason(tester);
    final animalId = await createAnimal(id, 'Arrived during confirmation');
    await tester.tap(find.byKey(const Key('confirm-archive-box-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('archive-blocking-animal-$animalId')),
      findsOneWidget,
    );
    expect((await boxes.getBoxById(id))!.status, BoxStatus.active);
  });

  testWidgets(
    'archived list supports cancel and duplicate-safe restore with the same QR',
    (tester) async {
      final id = await boxes.createBoxWithGeneratedQrId();
      await boxes.archiveBox(
        boxId: id,
        reason: BoxArchiveReason.damaged,
        archivedAt: DateTime(2026, 9, 13),
        archiveNotes: 'Cracked glass',
      );
      final qr = (await boxes.getBoxById(id))!.qrId;
      await pumpPage(tester, BoxesPage(database: database));
      expect(find.byKey(Key('box-list-item-$id')), findsNothing);
      await tester.tap(find.byKey(const Key('box-archive-button')));
      await tester.pumpAndSettle();
      expect(find.text('Archived Boxes'), findsOneWidget);
      expect(find.byKey(const Key('add-box-button')), findsNothing);
      await tester.tap(find.byKey(Key('archived-box-list-item-$id')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-box-button')), findsNothing);
      expect(find.byKey(const Key('box-archived-status')), findsOneWidget);
      expect(find.text('Damaged'), findsOneWidget);
      expect(find.text('Cracked glass'), findsOneWidget);
      await tester.tap(find.byKey(const Key('restore-box-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel-restore-box-button')));
      await tester.pumpAndSettle();
      expect((await boxes.getBoxById(id))!.status, BoxStatus.archived);
      await tester.tap(find.byKey(const Key('restore-box-button')));
      await tester.pumpAndSettle();
      final confirm = tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-restore-box-button')),
          )
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(find.byType(BoxDetailPage), findsNothing);
      expect(find.text('No archived Boxes'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(Key('box-list-item-$id')), findsOneWidget);
      final restored = (await boxes.getBoxById(id))!;
      expect(restored.qrId, qr);
      expect(restored.status, BoxStatus.active);
      expect(restored.archiveReason, isNull);
      expect(restored.archiveNotes, isNull);
      expect(restored.archivedAt, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('archived Box cannot be edited through a direct edit route', (
    tester,
  ) async {
    final id = await boxes.createBoxWithGeneratedQrId();
    await boxes.archiveBox(
      boxId: id,
      reason: BoxArchiveReason.other,
      archivedAt: DateTime.now(),
    );
    await pumpPage(tester, BoxEditPage(database: database, boxId: id));
    expect(
      find.textContaining('Archived Boxes cannot be edited'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('save-box-button')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('box-name-field')), findsNothing);
  });

  testWidgets('German archive dialog fits a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final id = await boxes.createBoxWithGeneratedQrId();
    await pumpPage(
      tester,
      BoxEditPage(database: database, boxId: id),
      language: 'de',
    );
    await openArchiveDialog(tester);
    expect(find.text('Box archivieren'), findsWidgets);
    await selectReason(tester, label: 'Beschädigt');
    expect(find.text('Archivieren'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
