import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/media_repository.dart';
import 'package:terramanager/features/boxes/presentation/pages/new_box_page.dart';
import 'package:terramanager/features/media/presentation/picture_selection_flow.dart';
import 'package:terramanager/features/media/presentation/widgets/picture_selection_controls.dart';

import '../../../media/presentation/fake_picture_selection_flow.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    PictureSelectionFlow? pictureSelectionFlow,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewBoxPage(
          database: database,
          pictureSelectionFlow: pictureSelectionFlow,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> pumpPageWithNavigation(
    WidgetTester tester, {
    PictureSelectionFlow? pictureSelectionFlow,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-new-box-button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NewBoxPage(
                          database: database,
                          pictureSelectionFlow: pictureSelectionFlow,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open New Box'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-new-box-button')));

    await tester.pumpAndSettle();
  }

  testWidgets('shows new box screen', (tester) async {
    await pumpPage(tester);

    expect(find.text('New Box'), findsOneWidget);

    expect(find.text('Create a new box'), findsOneWidget);

    expect(
      find.text(
        'A permanent unique QR identifier will be generated automatically.',
      ),
      findsOneWidget,
    );

    expect(find.byKey(const Key('new-box-picture')), findsOneWidget);

    expect(
      find.byKey(const Key('select-new-box-picture-button')),
      findsOneWidget,
    );

    expect(find.text('Add Picture'), findsOneWidget);

    expect(find.byKey(const Key('new-box-width-field')), findsOneWidget);

    expect(find.byKey(const Key('new-box-height-field')), findsOneWidget);

    expect(find.byKey(const Key('new-box-depth-field')), findsOneWidget);

    expect(find.text('Format: TM:BOX:<UUID>'), findsOneWidget);

    expect(find.byKey(const Key('create-box-button')), findsOneWidget);
  });

  testWidgets('does not require manual QR ID', (tester) async {
    await pumpPage(tester);

    expect(find.byType(TextFormField), findsNWidgets(3));

    expect(find.byKey(const Key('new-box-width-field')), findsOneWidget);

    expect(find.byKey(const Key('new-box-height-field')), findsOneWidget);

    expect(find.byKey(const Key('new-box-depth-field')), findsOneWidget);

    expect(find.text('Format: TM:BOX:<UUID>'), findsOneWidget);

    expect(find.byKey(const Key('qr-id-field')), findsNothing);
  });

  testWidgets('creates box with generated QR ID', (tester) async {
    await pumpPageWithNavigation(tester);

    final createButton = find.byKey(const Key('create-box-button'));

    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();

    await tester.tap(createButton);
    await tester.pumpAndSettle();

    final boxes = await BoxRepository(database).getAllBoxes();

    expect(boxes.length, 1);

    final box = boxes.single;

    expect(box.qrId, startsWith('TM:BOX:'));

    expect(
      box.qrId,
      matches(
        RegExp(
          r'^TM:BOX:'
          r'[0-9a-f]{8}-'
          r'[0-9a-f]{4}-'
          r'4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
  });

  testWidgets('returns to previous page after successful creation', (
    tester,
  ) async {
    await pumpPageWithNavigation(tester);

    final createButton = find.byKey(const Key('create-box-button'));

    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();

    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('New Box'), findsNothing);

    expect(find.text('Open New Box'), findsOneWidget);
  });

  testWidgets('stores one normalized picture and blocks duplicate actions', (
    tester,
  ) async {
    final selection = Completer<SelectedPicture?>();
    final flow = FakePictureSelectionFlow(pendingResult: selection.future);

    await pumpPageWithNavigation(tester, pictureSelectionFlow: flow);

    await tester.tap(find.byKey(const Key('select-new-box-picture-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PictureSelectionControls.galleryOptionKey));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(flow.selectedSources, [ImageSource.gallery]);
    expect(
      find.byKey(PictureSelectionControls.processingIndicatorKey),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('select-new-box-picture-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('create-box-button')))
          .onPressed,
      isNull,
    );

    selection.complete(normalizedTestPicture('cropped-box.webp'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(PictureSelectionControls.processingIndicatorKey),
      findsNothing,
    );
    expect(find.text('No picture'), findsNothing);

    final createButton = find.byKey(const Key('create-box-button'));
    await tester.ensureVisible(createButton);
    final createAction = tester.widget<FilledButton>(createButton).onPressed!;
    createAction();
    createAction();
    await tester.pumpAndSettle();

    final box = (await BoxRepository(database).getAllBoxes()).single;
    final media = await MediaRepository(database)
        .getMediaById(box.pictureMediaId!);
    final allMedia = await database.select(database.mediaAssets).get();

    expect(media, isNotNull);
    expect(media!.fileName, 'cropped-box.webp');
    expect(media.mimeType, 'image/webp');
    expect(media.data, normalizedTestPictureBytes);
    expect(allMedia, hasLength(1));
  });
}
