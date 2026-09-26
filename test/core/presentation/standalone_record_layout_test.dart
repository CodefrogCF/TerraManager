import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_edit_page.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_weight_history_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_edit_page.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_history_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('standalone records share reading widths across route types', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.test(NativeDatabase.memory());
    addTearDown(database.close);
    final boxes = BoxRepository(database);
    final boxId = await boxes.createBox('TMBOX-LAYOUT-TEST');
    final box = (await boxes.getBoxById(boxId))!;
    final animalId = await AnimalRepository(database).createAnimal(
      boxId: boxId,
      commonName: 'Corn snake',
      latinName: 'Pantherophis guttatus',
      tempMin: 24,
      tempMax: 28,
      humidityMin: 40,
      humidityMax: 60,
    );
    final pages = <Widget Function()>[
      () => BoxDetailPage(database: database, box: box),
      () => AnimalDetailPage(database: database, animalId: animalId),
      () => BoxEditPage(database: database, boxId: boxId),
      () => AnimalEditPage(database: database, animalId: animalId),
      () => BoxHistoryPage(database: database),
      () => AnimalWeightHistoryPage(database: database, animalId: animalId),
    ];
    for (final size in [
      const Size(1920, 1080),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      final width = size.width;
      tester.view.physicalSize = size;
      for (final page in pages) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: page(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(Scaffold)).width,
          width.clamp(0, 960),
        );
        final content = tester.widget<ConstrainedPageWidth>(
          find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedPageWidth && widget.maxWidth == 760,
          ),
        );
        expect(
          tester.getSize(find.byWidget(content.child)).width,
          width.clamp(0, 760),
        );
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
