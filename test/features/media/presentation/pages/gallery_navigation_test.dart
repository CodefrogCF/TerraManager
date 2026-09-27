import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/media/presentation/pages/full_screen_image_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

final _bytes = base64Decode(
  'UklGRjYAAABXRUJQVlA4ICoAAACwAQCdASoCAAIAAgA0JaACdLoABGaAAP7udn/3BmfV2OH9zcW5+hQAAAA=',
);
final _providers = [
  for (var i = 0; i < 3; i++) MemoryImage(Uint8List.fromList(_bytes)),
];
final _image = find.byKey(const Key('full-screen-image'));
final _viewer = find.byKey(const Key('full-screen-image-viewer'));
final _next = find.byKey(const Key('next-full-screen-picture'));
final _previous = find.byKey(const Key('previous-full-screen-picture'));

void main() {
  testWidgets(
    'gallery starts at selection and buttons and keyboard respect both boundaries',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenImagePage.gallery(
            imageProviders: _providers,
            initialIndex: 1,
            title: 'Gallery',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 of 3'), findsOneWidget);
      expect(tester.widget<Image>(_image).image, _providers[1]);
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('3 of 3'), findsOneWidget);
      expect(tester.widget<IconButton>(_next).onPressed, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(_image).image, _providers[1]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('1 of 3'), findsOneWidget);
      expect(tester.widget<IconButton>(_previous).onPressed, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('1 of 3'), findsOneWidget);
    },
  );

  testWidgets(
    'horizontal swipes change pictures but a zoomed drag pans the same image',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenImagePage.gallery(
            imageProviders: _providers,
            title: 'Gallery',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(_viewer, const Offset(-160, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 of 3'), findsOneWidget);
      final controller = tester
          .widget<InteractiveViewer>(_viewer)
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();
      await tester.drag(_viewer, const Offset(-140, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 of 3'), findsOneWidget);
      expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('3 of 3'), findsOneWidget);
      expect(
        tester
            .widget<InteractiveViewer>(_viewer)
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        1,
      );
    },
  );

  testWidgets('pinching zooms without navigating the gallery', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FullScreenImagePage.gallery(
          imageProviders: _providers,
          title: 'Gallery',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final center = tester.getCenter(_viewer);
    final left = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 1,
    );
    final right = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await tester.pump();
    await left.moveTo(center - const Offset(80, 0));
    await right.moveTo(center + const Offset(80, 0));
    await tester.pump();
    await left.moveTo(center - const Offset(110, 0));
    await right.moveTo(center + const Offset(110, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);
    expect(
      tester
          .widget<InteractiveViewer>(_viewer)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      greaterThan(1),
    );
  });

  testWidgets(
    'a failed picture does not block navigation and a single gallery has disabled controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenImagePage.gallery(
            imageProviders: [
              MemoryImage(Uint8List.fromList([0, 1])),
              _providers.first,
            ],
            title: 'Gallery',
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Image unavailable'), findsOneWidget);
      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(tester.widget<Image>(_image).image, _providers.first);
      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenImagePage(imageBytes: _bytes, title: 'Single'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 of 1'), findsOneWidget);
      expect(tester.widget<IconButton>(_next).onPressed, isNull);
      expect(tester.widget<IconButton>(_previous).onPressed, isNull);
    },
  );

  for (final animalOwner in [false, true]) {
    testWidgets(
      'standalone ${animalOwner ? 'Animal' : 'Box'} detail primary opens the ordered gallery and returns to details',
      (tester) async {
        final db = AppDatabase.test(NativeDatabase.memory());
        addTearDown(db.close);
        final box = await BoxRepository(db)
            .createBoxWithGeneratedQrId(name: 'Original Box');
        final animal = await AnimalRepository(db).createAnimal(
          boxId: box,
          commonName: 'Original Animal',
          latinName: 'Species',
          tempMin: 20,
          tempMax: 30,
          humidityMin: 40,
          humidityMax: 60,
        );
        final repo = PictureGalleryRepository(db);
        final ids = <int>[];
        for (var i = 0; i < 3; i++) {
          ids.add(
            animalOwner
                ? await repo.addAnimalPicture(
                    animalId: animal,
                    fileName: '$i.webp',
                    mimeType: 'image/webp',
                    data: _bytes,
                    makePrimary: i == 1,
                  )
                : await repo.addBoxPicture(
                    boxId: box,
                    fileName: '$i.webp',
                    mimeType: 'image/webp',
                    data: _bytes,
                    makePrimary: i == 1,
                  ),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: animalOwner
                ? AnimalDetailPage(database: db, animalId: animal)
                : BoxDetailPage(
                    database: db,
                    box: (await BoxRepository(db).getBoxById(box))!,
                  ),
          ),
        );
        await tester.pumpAndSettle();
        final opener = find.byKey(
          Key('open-${animalOwner ? 'animal' : 'box'}-picture-button'),
        );
        await tester.ensureVisible(opener);
        await tester.tap(opener);
        await tester.pumpAndSettle();
        expect(find.text('2 of 3'), findsOneWidget);
        await tester.tap(_previous);
        await tester.pumpAndSettle();
        expect(find.text('1 of 3'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('close-full-screen-image-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(animalOwner ? AnimalDetailPage : BoxDetailPage),
          findsOneWidget,
        );
        expect(
          (animalOwner
                  ? await repo.getAnimalPictures(animal)
                  : await repo.getBoxPictures(box))
              .map((entry) => entry.media.id),
          ids,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(320, 844), const Size(1280, 900)]) {
    testWidgets('German gallery controls fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FullScreenImagePage.gallery(
            imageProviders: _providers,
            initialIndex: 1,
            title: 'Tierbilder',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 von 3'), findsOneWidget);
      expect(tester.getRect(_next).right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    });
  }
}
