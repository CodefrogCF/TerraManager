import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/presentation/widgets/constrained_page_width.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_detail_pages.dart';
import 'package:terramanager/shared_client/shared_forms.dart';
import 'package:terramanager/shared_client/shared_history_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shared detail, edit and care history fit desktop and phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    final box = <String, dynamic>{
      'id': 1,
      'name': 'Terrarium',
      'status': 'active',
    };
    final animal = <String, dynamic>{
      'id': 1,
      'boxId': 1,
      'commonName': 'Corn snake',
      'latinName': 'Pantherophis guttatus',
      'category': 'reptile',
      'status': 'active',
      'tempMin': 24.0,
      'tempMax': 28.0,
      'humidityMin': 40.0,
      'humidityMax': 60.0,
    };
    final api = SharedApiClient(
      Uri.parse('https://192.168.1.117'),
      MockClient((request) async {
        final path = request.url.path;
        final key = path.split('/').last;
        final Object payload = switch (path) {
          '/api/v1/boxes/1' => {'box': box},
          '/api/v1/animals/1' => {'animal': animal},
          _ => {key: <Object>[]},
        };
        return http.Response(jsonEncode(payload), 200);
      }),
    );
    addTearDown(api.close);
    final pages = <Widget Function()>[
      () => SharedBoxDetailPage(
        api: api,
        id: 1,
        boxes: [box],
        animals: [animal],
        connected: true,
        change: (_) async => true,
      ),
      () => SharedAnimalDetailPage(
        api: api,
        id: 1,
        boxes: [box],
        connected: true,
        change: (_) async => true,
      ),
      () => SharedBoxForm(api: api, change: (_) async => true),
      () => SharedBoxForm(api: api, initial: box, change: (_) async => true),
      () => SharedAnimalForm(api: api, boxes: [box], change: (_) async => true),
      () => SharedAnimalForm(
        api: api,
        boxes: [box],
        initial: animal,
        change: (_) async => true,
      ),
      for (final kind in SharedHistoryKind.values)
        () => SharedHistoryPage(
          api: api,
          animalId: 1,
          kind: kind,
          active: true,
          change: (_) async => true,
        ),
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
          AppSettingsScope(
            controller: settings,
            child: MaterialApp(
              theme: ThemeData.dark(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: page(),
            ),
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
