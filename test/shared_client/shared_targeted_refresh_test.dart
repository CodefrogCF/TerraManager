import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/shared_client/app/shared_care_app.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_detail_page.dart';
import 'package:terramanager/shared_client/media/presentation/widgets/shared_picture_gallery.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

class _Backend {
  int revision = 0;
  bool forceReset = false;
  List<Map<String, dynamic>> pictures = [];
  final boxes = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Home', 'status': 'active'},
    {
      'id': 2,
      'name': 'Archived Home',
      'status': 'archived',
      'archiveReason': 'stored',
      'archivedAt': '2026-10-01T00:00:00Z',
    },
  ];
  final reads = <String, int>{};
  final animal = <String, dynamic>{
    'id': 7,
    'status': 'active',
    'revision': 'r0',
    'boxId': 1,
    'commonName': 'Gizmo',
    'latinName': 'Example species',
    'category': 'reptile',
    'notes': 'Long detail notes ' * 30,
  };
  Map<String, Object?> hints = {};
  List<Map<String, dynamic>> feedings = [];
  http.Response ok(String key, Object value) =>
      http.Response(jsonEncode({key: value}), 200);
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    reads.update(path, (n) => n + 1, ifAbsent: () => 1);
    switch (path) {
      case '/api/v1/auth/session':
      case '/api/v1/auth/login':
        return http.Response(
          jsonEncode({
            'user': {'username': 'carer', 'role': 'caregiver'},
            'csrfToken': 'csrf',
          }),
          200,
        );
      case '/api/v1/changes':
        final cursor = 'c$revision';
        if (request.url.queryParameters['since'] == cursor) {
          return http.Response(
            '',
            304,
            headers: {'x-shared-care-cursor': cursor},
          );
        }
        return http.Response(
          jsonEncode({
            'cursor': cursor,
            'epoch': 'test',
            'revision': revision,
            'preferencesRevision': 0,
            'reset': forceReset || request.url.queryParameters['since'] == null,
            'preferencesChanged': false,
            'changes': [
              {'resources': hints},
            ],
          }),
          200,
        );
      case '/api/v1/animals/7':
        return ok('animal', animal);
      case '/api/v1/animals/7/feedings':
        return ok('feedings', feedings);
      case '/api/v1/animals/7/weights':
        return ok('weights', []);
      case '/api/v1/animals/7/shedding':
        return ok('shedding', []);
      case '/api/v1/animals/7/pictures':
        return ok('pictures', pictures);
      case '/api/v1/boxes':
        return ok('boxes', boxes);
      case '/api/v1/animals':
        return ok('animals', [animal]);
      case '/api/v1/reminders':
        return ok('reminders', []);
      case '/api/v1/auth/preferences':
        return ok('preferences', {});
    }
    return http.Response('{}', 404);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<SharedApiClient> open(WidgetTester tester, _Backend backend) async {
    final api = SharedApiClient(
      Uri.parse('https://localhost'),
      MockClient(backend.handle),
      syncNow: tester.binding.clock.now,
      syncRandom: () => 0,
    );
    await api.login('carer', 'password');
    final settings = AppSettingsController();
    addTearDown(settings.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SharedAnimalDetailPage(
            api: api,
            id: 7,
            boxes: const [],
            connected: true,
            change: (op) async {
              await op();
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await api.refresh.reconcile();
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets(
    '304 keeps detail, gallery metadata, history futures and scroll stable',
    (tester) async {
      final backend = _Backend();
      final api = await open(tester, backend);
      final gallery = tester.state(find.byType(SharedPictureGallery));
      final list = find.byKey(const ValueKey('shared-animal-detail-list-7'));
      await tester.drag(list, const Offset(0, -250));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      final offset = scroll.position.pixels;
      final before = Map.of(backend.reads)..remove('/api/v1/changes');
      for (var i = 0; i < 4; i++) {
        await api.refresh.reconcile();
      }
      await tester.pumpAndSettle();
      expect(Map.of(backend.reads)..remove('/api/v1/changes'), before);
      expect(
        identical(tester.state(find.byType(SharedPictureGallery)), gallery),
        isTrue,
      );
      expect(scroll.position.pixels, offset);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Feeding update reloads only its detail dependencies and retains gallery',
    (tester) async {
      final backend = _Backend();
      final api = await open(tester, backend);
      final gallery = tester.state(find.byType(SharedPictureGallery));
      final before = Map.of(backend.reads);
      backend.revision++;
      backend.hints = {
        'animals': [7],
        'reminders': [7],
        'feedingHistories': [7],
      };
      backend.feedings = [
        {'id': 3, 'animalId': 7, 'fedAt': '2026-10-18T08:00:00Z', 'notes': ''},
      ];
      await api.refresh.reconcile();
      await tester.pumpAndSettle();
      expect(
        backend.reads['/api/v1/animals/7/feedings'],
        before['/api/v1/animals/7/feedings']! + 1,
      );
      for (final path in [
        '/api/v1/animals/7/pictures',
        '/api/v1/animals/7/weights',
        '/api/v1/animals/7/shedding',
        '/api/v1/boxes',
      ]) {
        expect(backend.reads[path], before[path], reason: path);
      }
      expect(
        identical(tester.state(find.byType(SharedPictureGallery)), gallery),
        isTrue,
      );
      expect(api.refresh.appliedCursor, 'c1');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'remote change retains an unsaved form and defers the hidden detail read',
    (tester) async {
      final backend = _Backend();
      final api = await open(tester, backend);
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      final input = find.byType(TextFormField).first;
      await tester.enterText(input, 'Unsaved local draft');
      final before = backend.reads['/api/v1/animals/7'];
      backend.revision++;
      backend.hints = {
        'animals': [7],
      };
      backend.animal['commonName'] = 'Changed remotely';
      await api.refresh.reconcile();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(input).controller!.text,
        'Unsaved local draft',
      );
      expect(backend.reads['/api/v1/animals/7'], before);
      expect(find.text('Unsaved local draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reset changes detail image provider keys when media IDs are reused',
    (tester) async {
      final backend = _Backend()
        ..pictures = [
          {'mediaId': 42, 'isPrimary': true},
        ];
      final api = await open(tester, backend);
      final gallery = find.byType(SharedPictureGallery);
      final state = tester.state(gallery);
      final previous = tester
          .widget<Image>(
            find.descendant(of: gallery, matching: find.byType(Image)).first,
          )
          .image;
      final previousUrl = api.mediaUrl(42);
      backend.revision++;
      backend.forceReset = true;
      await api.refresh.reconcile();
      await tester.pumpAndSettle();
      final current = tester
          .widget<Image>(
            find.descendant(of: gallery, matching: find.byType(Image)).first,
          )
          .image;
      expect(current, isNot(previous));
      expect(api.mediaUrl(42), isNot(previousUrl));
      expect(identical(tester.state(gallery), state), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reset reloads overview bytes even when the media ID stays the same',
    (tester) async {
      final backend = _Backend();
      backend.animal['pictureMediaId'] = 42;
      final api = SharedApiClient(
        Uri.parse('https://localhost'),
        MockClient(backend.handle),
        syncNow: tester.binding.clock.now,
        syncRandom: () => 0,
      );
      await tester.pumpWidget(SharedCareApp(api: api));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.pets_outlined));
      await tester.pumpAndSettle();
      await api.refresh.reconcile();
      await tester.pumpAndSettle();
      final reads = backend.reads['/api/v1/media/42']!;
      backend.revision++;
      backend.forceReset = true;
      await api.refresh.reconcile();
      await tester.pumpAndSettle();
      expect(backend.reads['/api/v1/media/42'], reads + 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final kind in ['boxes', 'animals']) {
    testWidgets(
      'visible $kind archive receives targeted updates while home is hidden',
      (tester) async {
        final backend = _Backend();
        if (kind == 'animals') backend.animal['status'] = 'archived';
        final api = SharedApiClient(
          Uri.parse('https://localhost'),
          MockClient(backend.handle),
          syncNow: tester.binding.clock.now,
          syncRandom: () => 0,
        );
        await tester.pumpWidget(SharedCareApp(api: api));
        await tester.pumpAndSettle();
        await api.refresh.reconcile();
        await tester.pumpAndSettle();
        if (kind == 'animals') {
          await tester.tap(find.byIcon(Icons.pets_outlined));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.byKey(
            Key(
              kind == 'boxes' ? 'box-archive-button' : 'animal-history-button',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final previousName = kind == 'boxes' ? 'Archived Home' : 'Gizmo';
        expect(find.text(previousName), findsOneWidget);
        if (kind == 'boxes') {
          backend.boxes[1] = {
            ...backend.boxes[1],
            'name': 'Remote archived name',
          };
        } else {
          backend.animal['commonName'] = 'Remote archived name';
        }
        backend.revision++;
        backend.hints = {
          kind: [kind == 'boxes' ? 2 : 7],
        };
        await api.refresh.reconcile();
        await tester.pumpAndSettle();
        expect(find.text('Remote archived name'), findsOneWidget);
        expect(find.text(previousName), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
