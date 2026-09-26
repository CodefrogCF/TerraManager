import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_collection_pages.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+'
  'A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final kind in ['box', 'animal']) {
    testWidgets(
      '$kind overview reuses HTTP pictures across scrolling, polling, grids and archives',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = AppSettingsController();
        final reads = <int, int>{};
        var records = <Map<String, dynamic>>[
          for (var id = 1; id <= 40; id++)
            {
              'id': id,
              'name': 'Box $id',
              'commonName': 'Animal $id',
              'latinName': 'Species $id',
              'status': 'active',
              'boxId': 1,
              'pictureMediaId': id,
            },
          {
            'id': 101,
            'name': 'Archive',
            'commonName': 'Archive',
            'status': 'archived',
            'boxId': 1,
            'pictureMediaId': 101,
          },
        ];
        final api = SharedApiClient(
          Uri.parse('https://192.168.1.117'),
          MockClient((request) async {
            final path = request.url.path;
            if (path.startsWith('/api/v1/media/')) {
              final id = int.parse(request.url.pathSegments.last);
              reads.update(id, (count) => count + 1, ifAbsent: () => 1);
              return http.Response.bytes(
                _png,
                200,
                headers: {'content-type': 'image/png'},
              );
            }
            if (path.endsWith('/pictures')) {
              return http.Response('{"pictures":[]}', 200);
            }
            if (path.endsWith('/feedings')) {
              return http.Response('{"feedings":[]}', 200);
            }
            if (path.endsWith('/weights')) {
              return http.Response('{"weights":[]}', 200);
            }
            if (path.endsWith('/shedding')) {
              return http.Response('{"shedding":[]}', 200);
            }
            if (path == '/api/v1/boxes') {
              return http.Response(jsonEncode({'boxes': records}), 200);
            }
            if (path == '/api/v1/animals') {
              return http.Response(jsonEncode({'animals': records}), 200);
            }
            if (path == '/api/v1/boxes/1' || path == '/api/v1/animals/1') {
              // This test isolates overview requests from the detail gallery.
              return http.Response(
                jsonEncode({
                  kind: {...records.first, 'pictureMediaId': null},
                }),
                200,
              );
            }
            return http.Response('{}', 404);
          }),
        );
        addTearDown(settings.dispose);
        addTearDown(api.close);
        Widget app() => AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: kind == 'box'
                ? SharedBoxesPage(
                    api: api,
                    boxes: records,
                    animals: const [],
                    connected: true,
                    change: (_) async => true,
                    onReload: () async {},
                  )
                : SharedAnimalsPage(
                    api: api,
                    animals: records,
                    boxes: const [],
                    connected: true,
                    change: (_) async => true,
                    onReload: () async {},
                  ),
          ),
        );
        Future<void> top() async {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(reads[1], 1);
        await tester.scrollUntilVisible(
          find.byKey(Key('$kind-list-item-30')),
          500,
        );
        await top();
        expect(reads[1], 1);
        records = records
            .map(
              (r) => {
                ...r,
                'revision': 'new-revision',
                'latestFeedingAt': '2026-09-26T12:00:00Z',
              },
            )
            .toList();
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(reads[1], 1);
        await settings.setBigPictureModeEnabled(true);
        await tester.pumpAndSettle();
        expect(find.byKey(Key('$kind-big-picture-1')), findsOneWidget);
        expect(reads[1], 1);
        await tester.tap(
          find.byKey(
            Key(kind == 'box' ? 'box-archive-button' : 'animal-history-button'),
          ),
        );
        await tester.pumpAndSettle();
        expect(reads[101], 1);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(reads[1], 1);
        await settings.setBigPictureModeEnabled(false);
        await tester.pumpAndSettle();
        await top();
        final secondReads = reads[2];
        records = [
          {...records.first, 'pictureMediaId': 200},
          ...records.skip(1),
        ];
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(reads[200], 1);
        expect(reads[2], secondReads);
        await tester.tap(find.byKey(const Key('shared-refresh')));
        await tester.pumpAndSettle();
        expect(reads[200], 2);
        await tester.tap(find.byKey(Key('$kind-list-item-1')));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(reads[200], 3);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(reads[200], 4);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
