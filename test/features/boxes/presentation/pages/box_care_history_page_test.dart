import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/boxes/domain/box_care_entry.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_care_history_page.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    required String language,
    required Future<BoxCareHistoryData> Function() load,
    required SaveBoxCare save,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: BoxCareHistoryPage(
          boxLabel: 'Test Box',
          load: load,
          save: save,
          delete: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['de', 'en']) {
    testWidgets(
      '$language records localized care on narrow screens without picture controls',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final entries = <BoxCareEntry>[];
        await show(
          tester,
          language: language,
          load: () async => BoxCareHistoryData(entries: entries, active: true),
          save:
              ({
                existing,
                required type,
                customTypeId,
                required occurredAt,
                notes,
                required requestId,
              }) async {
                expect(type, BoxCareEventType.waterChange);
                expect(notes, 'Changed the water');
                entries.add(
                  BoxCareEntry(
                    id: 1,
                    boxId: 1,
                    type: type,
                    occurredAt: occurredAt,
                    notes: notes,
                    revision: 1,
                    requestId: 'widget-fixture',
                  ),
                );
                return true;
              },
        );
        await tester.tap(find.byKey(const Key('add-box-care-event')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('box-care-dialog')), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byIcon(Icons.calendar_today), findsOneWidget);
        await tester.tap(find.byKey(const Key('box-care-type')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(language == 'de' ? 'Wasserwechsel' : 'Water change').last,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('box-care-notes')),
          'Changed the water',
        );
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
        expect(find.byType(Image), findsNothing);
        await tester.tap(find.byKey(const Key('save-box-care-event')));
        await tester.pumpAndSettle();
        expect(entries, hasLength(1));
        expect(find.byType(AlertDialog), findsNothing);
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('box-care-event-1')),
          200,
        );
        expect(find.text('Changed the water'), findsOneWidget);
        expect(find.byType(Card), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'failed save retains draft and retry ID without reporting success',
    (tester) async {
      final ids = <String>[];
      final notes = <String?>[];
      await show(
        tester,
        language: 'en',
        load: () async => const BoxCareHistoryData(entries: [], active: true),
        save:
            ({
              existing,
              required type,
              customTypeId,
              required occurredAt,
              notes,
              required requestId,
            }) async {
              ids.add(requestId);
              return false;
            },
      );
      await tester.tap(find.byKey(const Key('add-box-care-event')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('box-care-notes')),
        'Keep this unsaved note',
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.byKey(const Key('save-box-care-event')));
        await tester.pumpAndSettle();
        notes.add(
          tester
              .widget<TextField>(find.byKey(const Key('box-care-notes')))
              .controller!
              .text,
        );
      }
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(1));
      expect(notes, ['Keep this unsaved note', 'Keep this unsaved note']);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
  testWidgets('editing a care entry updates its note without media controls', (
    tester,
  ) async {
    final entry = BoxCareEntry(
      id: 1,
      boxId: 1,
      type: BoxCareEventType.cleaning,
      occurredAt: DateTime.utc(2026, 1, 1),
      revision: 1,
      requestId: 'existing-with-picture',
    );
    var saved = false;
    await show(
      tester,
      language: 'en',
      load: () async => BoxCareHistoryData(entries: [entry], active: true),
      save:
          ({
            existing,
            required type,
            customTypeId,
            required occurredAt,
            notes,
            required requestId,
          }) async {
            expect(existing, same(entry));
            expect(notes, 'Updated note');
            saved = true;
            return true;
          },
    );
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.byKey(const ValueKey('edit-box-care-1')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    await tester.enterText(
      find.byKey(const Key('box-care-notes')),
      'Updated note',
    );
    await tester.tap(find.byKey(const Key('save-box-care-event')));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
  });

  testWidgets('archived histories are chronological and read-only', (
    tester,
  ) async {
    final at = DateTime.utc(2026, 1, 1);
    await show(
      tester,
      language: 'en',
      load: () async => BoxCareHistoryData(
        entries: [
          BoxCareEntry(
            id: 1,
            boxId: 1,
            type: BoxCareEventType.cleaning,
            occurredAt: at,
            revision: 1,
            requestId: 'widget-fixture',
          ),
          BoxCareEntry(
            id: 2,
            boxId: 1,
            type: BoxCareEventType.waterChange,
            occurredAt: at.add(const Duration(days: 1)),
            revision: 1,
            requestId: 'widget-fixture',
          ),
        ],
        active: false,
      ),
      save: ({
        existing,
        required type,
        customTypeId,
        required occurredAt,
        notes,
        required requestId,
      }) async => throw StateError('Read-only'),
    );
    expect(find.byKey(const Key('add-box-care-event')), findsNothing);
    expect(find.byKey(const ValueKey('edit-box-care-1')), findsNothing);
    expect(
      tester.getTopLeft(find.text('Water change')).dy,
      lessThan(tester.getTopLeft(find.text('Cleaning')).dy),
    );
  });
}
