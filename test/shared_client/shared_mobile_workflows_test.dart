import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/features/settings/archive_sort_order.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart';
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_boxes_page.dart';
import 'package:terramanager/shared_client/care_history/presentation/pages/shared_history_page.dart';
import 'package:terramanager/shared_client/media/presentation/widgets/shared_picture_gallery.dart';
import 'package:terramanager/shared_client/navigation/infrastructure/serialized_browser_history.dart';
import 'package:terramanager/shared_client/navigation/presentation/shared_browser_back_observer.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

// A real browser delivers programmatic history.go() later, after a menu's
// onSelected callback has already opened the next dialog.
class _DelayedHistory extends SerializedBrowserHistory {
  late void Function(int) changed;
  int current = 0;
  int? pending;
  final reported = <int>[];
  @override
  Future<void> start(void Function(int) callback) async => changed = callback;
  @override
  Future<void> report(int depth, {required bool replace}) async {
    current = depth;
    reported.add(depth);
  }

  @override
  void traverse(int count) => pending = current - count;
  @override
  void stop() {}
  void deliverTraversal() {
    expect(pending, isNotNull);
    current = pending!;
    pending = null;
    changed(current);
  }
}

const _boxes = <Map<String, dynamic>>[
  {'id': 1, 'name': 'Box', 'status': 'active'},
];
const _animals = <Map<String, dynamic>>[
  {'id': 2, 'commonName': 'Animal', 'boxId': 1, 'status': 'active'},
];

Widget _app(
  Widget home,
  AppSettingsController settings, {
  NavigatorObserver? observer,
}) => AppSettingsScope(
  controller: settings,
  child: MaterialApp(
    navigatorObservers: [?observer],
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
    home: home,
  ),
);

http.Response _json(Object value) => http.Response(jsonEncode(value), 200);
http.Response _session() => _json({
  'user': {'username': 'admin', 'role': 'administrator'},
  'csrfToken': 'csrf',
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final animals in [false, true]) {
    for (final duplicate in [false, true]) {
      testWidgets(
        'touch ${animals ? 'Animal' : 'Box'} ${duplicate ? 'duplicate' : 'archive'} survives delayed menu Back and sends one mutation',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final history = _DelayedHistory();
          final observer = SharedBrowserBackObserver(history: history);
          final settings = AppSettingsController();
          final writes = <http.Request>[];
          final api = SharedApiClient(
            Uri.parse('https://localhost'),
            MockClient((request) async {
              if (request.url.path.endsWith('/login')) return _session();
              if (request.method == 'POST') writes.add(request);
              return _json({
                'box': {'id': 3},
                'animal': {'id': 3},
              });
            }),
          );
          addTearDown(api.close);
          addTearDown(settings.dispose);
          addTearDown(observer.dispose);
          await api.login('admin', 'password');
          Future<bool> change(Future<void> Function() mutation) async {
            await mutation();
            return true;
          }

          await tester.pumpWidget(
            _app(
              animals
                  ? SharedAnimalsPage(
                      api: api,
                      boxes: _boxes,
                      animals: _animals,
                      connected: true,
                      change: change,
                      onReload: () async {},
                    )
                  : SharedBoxesPage(
                      api: api,
                      boxes: _boxes,
                      animals: _animals,
                      connected: true,
                      change: change,
                      onReload: () async {},
                    ),
              settings,
              observer: observer,
            ),
          );
          await tester.pumpAndSettle();
          await tester.longPress(
            find.byKey(
              Key(
                '${animals ? 'animal' : 'box'}-context-menu-region-${animals ? 2 : 1}',
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(
              '${duplicate ? 'Duplicate' : 'Archive'} ${animals ? 'Animal' : 'Box'}',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(history.pending, 0);
          // The new dialog's history write waits until the old menu traversal has
          // completed. Its popstate echo must never close the confirmation.
          expect(history.reported, [0, 1]);
          history.deliverTraversal();
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(history.current, 1);
          expect(writes, isEmpty);
          if (duplicate) {
            await tester.enterText(
              find.byKey(const Key('duplicate-name')),
              'Copy',
            );
          }
          await tester.tap(
            duplicate
                ? find.byKey(const Key('confirm-shared-duplicate'))
                : find.widgetWithText(FilledButton, 'Archive'),
          );
          await tester.pumpAndSettle();
          expect(writes, hasLength(1));
          expect(
            writes.single.url.path,
            '/api/v1/${animals ? 'animals/2' : 'boxes/1'}/${duplicate ? 'duplicate' : 'archive'}',
          );
          history.deliverTraversal();
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      '${animals ? 'Animal' : 'Box'} archive is a list with metadata, independent sorting and a real Back route',
      (tester) async {
        final settings = AppSettingsController();
        await settings.setBigPictureModeEnabled(true);
        final records = <Map<String, dynamic>>[
          {
            'id': 2,
            'name': 'Box 10',
            'commonName': 'Animal 10',
            'status': 'archived',
            'archiveReason': 'sold',
            'archivedAt': '2020-02-03T12:00:00Z',
          },
          {
            'id': 3,
            'name': 'Box 2',
            'commonName': 'Animal 2',
            'status': 'archived',
            'archiveReason': 'other',
            'archivedAt': '2020-01-03T12:00:00Z',
          },
        ];
        final history = _DelayedHistory();
        final observer = SharedBrowserBackObserver(history: history);
        final api = SharedApiClient(
          Uri.parse('https://localhost'),
          MockClient((_) async => _json({})),
        );
        addTearDown(settings.dispose);
        addTearDown(observer.dispose);
        addTearDown(api.close);
        await tester.pumpWidget(
          _app(
            animals
                ? SharedAnimalsPage(
                    api: api,
                    boxes: _boxes,
                    animals: [..._animals, ...records],
                    connected: true,
                    change: (_) async => true,
                    onReload: () async {},
                  )
                : SharedBoxesPage(
                    api: api,
                    boxes: [..._boxes, ...records],
                    animals: _animals,
                    connected: true,
                    change: (_) async => true,
                    onReload: () async {},
                  ),
            settings,
            observer: observer,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            Key(animals ? 'animal-history-button' : 'box-archive-button'),
          ),
        );
        await tester.pumpAndSettle();
        expect(observer.depth, 1);
        final kind = animals ? 'animal' : 'box';
        expect(find.byKey(Key('$kind-big-picture-2')), findsNothing);
        expect(find.byKey(Key('$kind-list-item-2')), findsOneWidget);
        expect(find.byType(GridView), findsNothing);
        expect(find.textContaining('Sold'), findsOneWidget);
        expect(find.textContaining('Feb 3, 2020'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(Key('$kind-list-item-2'))).dy,
          lessThan(tester.getTopLeft(find.byKey(Key('$kind-list-item-3'))).dy),
        );
        await tester.tap(find.byKey(Key('$kind-archive-sort-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('$kind-archive-sort-option-archivedAt')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('$kind-archive-sort-option-name')),
          findsOneWidget,
        );
        expect(
          find.byType(CheckedPopupMenuItem<ArchiveSortCriterion>),
          findsNWidgets(2),
        );
        await tester.tap(find.byKey(Key('$kind-archive-sort-option-name')));
        await tester.pumpAndSettle();
        history.deliverTraversal();
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(Key('$kind-list-item-3'))).dy,
          lessThan(tester.getTopLeft(find.byKey(Key('$kind-list-item-2'))).dy),
        );
        expect(
          animals
              ? settings.animalArchiveSortOrder
              : settings.boxArchiveSortOrder,
          ArchiveSortOrder.nameAscending,
        );
        history.changed(0); // A mobile browser Back gesture.
        await tester.pumpAndSettle();
        expect(observer.depth, 0);
        expect(
          find.byKey(Key('$kind-big-picture-${animals ? 2 : 1}')),
          findsOneWidget,
        );
        expect(find.byKey(Key('$kind-list-item-3')), findsNothing);
        expect(settings.bigPictureModeEnabled, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'touch gallery deletion confirmation survives the menu traversal and deletes once',
    (tester) async {
      final history = _DelayedHistory();
      final observer = SharedBrowserBackObserver(history: history);
      final settings = AppSettingsController();
      var removed = 0;
      final api = SharedApiClient(
        Uri.parse('https://localhost'),
        MockClient((request) async {
          if (request.url.path.endsWith('/login')) return _session();
          if (request.method == 'DELETE') {
            removed++;
            return _json({});
          }
          return _json({
            'pictures': removed > 0
                ? []
                : [
                    {'mediaId': 42, 'isPrimary': true},
                  ],
          });
        }),
      );
      await api.login('admin', 'password');
      addTearDown(settings.dispose);
      addTearDown(observer.dispose);
      addTearDown(api.close);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: SharedPictureGallery(
                api: api,
                kind: 'animals',
                recordId: 2,
                active: true,
                change: (mutation) async {
                  await mutation();
                  return true;
                },
                onChanged: () {},
              ),
            ),
          ),
          settings,
          observer: observer,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete picture'));
      await tester.pumpAndSettle();
      history.deliverTraversal();
      await tester.pumpAndSettle();
      expect(find.text('Delete permanently?'), findsOneWidget);
      expect(removed, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      history.deliverTraversal();
      await tester.pumpAndSettle();
      expect(removed, 1);
      expect(find.text('Delete permanently?'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final kind in SharedHistoryKind.values) {
    testWidgets(
      '${kind.name} history accepts exact hour/minute input independently of the date and cancellation',
      (tester) async {
        final settings = AppSettingsController();
        final dateKey = switch (kind) {
          SharedHistoryKind.feedings => 'fedAt',
          SharedHistoryKind.weights => 'measuredAt',
          SharedHistoryKind.shedding => 'shedAt',
        };
        final writes = <Map<String, dynamic>>[];
        final api = SharedApiClient(
          Uri.parse('https://localhost'),
          MockClient((request) async {
            if (request.url.path.endsWith('/login')) return _session();
            if (request.method == 'PUT') {
              writes.add(jsonDecode(request.body) as Map<String, dynamic>);
              return _json({
                'feeding': {'id': 1},
                'weight': {'id': 1},
                'shedding': {'id': 1},
              });
            }
            return _json({
              kind.name: [
                {
                  'id': 1,
                  dateKey: DateTime(
                    2020,
                    2,
                    3,
                    18,
                    10,
                  ).toUtc().toIso8601String(),
                  'weightGrams': 12,
                },
              ],
            });
          }),
        );
        addTearDown(api.close);
        addTearDown(settings.dispose);
        await api.login('admin', 'password');
        await tester.pumpWidget(
          _app(
            SharedHistoryPage(
              api: api,
              animalId: 2,
              kind: kind,
              active: true,
              change: (mutation) async {
                await mutation();
                return true;
              },
            ),
            settings,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('shared-history-time')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TimePickerDialog>(find.byType(TimePickerDialog))
              .initialEntryMode,
          TimePickerEntryMode.input,
        );
        final inputs = find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(inputs.first, '19');
        await tester.enterText(inputs.last, '77');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.enterText(inputs.last, '37');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('shared-history-time')));
        await tester.pumpAndSettle();
        await tester.enterText(inputs.first, '22');
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(writes, hasLength(1));
        expect(
          DateTime.parse(writes.single[dateKey] as String).toLocal(),
          DateTime(2020, 2, 3, 19, 37),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
