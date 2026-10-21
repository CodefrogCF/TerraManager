import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/animal_repository.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';
import 'package:terramanager/features/settings/app_settings_controller.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart';

const _capture = Key('due-outline-capture');

Future<void> _checkEdges(WidgetTester tester, Finder tile, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  final rect = tester.getRect(tile).shift(-boundary.localToGlobal(Offset.zero));
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    final output = Platform.environment['TM_ISSUE_VISUAL_DIR'];
    if (output != null) {
      await Directory(output).create(recursive: true);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(png!.buffer.asUint8List());
    }
    final result = (bytes: bytes, width: image.width, height: image.height);
    image.dispose();
    return result;
  });
  final (:bytes, :width, :height) = captured!;
  // A white divider theme makes the original expanded outline visible. Sample
  // actual painted pixels at both card edges, away from the header's text.
  for (final y in [
    rect.top.floor(),
    rect.top.floor() + 1,
    rect.bottom.ceil() - 2,
    rect.bottom.ceil() - 1,
  ]) {
    for (final x in [
      rect.center.dx.round() - 20,
      rect.center.dx.round(),
      rect.center.dx.round() + 20,
    ]) {
      expect(y >= 0 && y < height && x >= 0 && x < width, isTrue);
      final offset = (y * width + x) * 4;
      final white =
          bytes[offset] > 245 &&
          bytes[offset + 1] > 245 &&
          bytes[offset + 2] > 245 &&
          bytes[offset + 3] > 245;
      expect(white, isFalse, reason: '$name has a white edge at ($x, $y)');
    }
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final shared in [false, true]) {
    for (final brightness in Brightness.values) {
      for (final count in [1, 2]) {
        final name =
            '${shared ? 'shared' : 'standalone'}_${brightness.name}_$count';
        testWidgets(
          '$name due summary has no white outline and keeps its toggle',
          (tester) async {
            final settings = AppSettingsController();
            addTearDown(settings.dispose);
            final now = DateTime.utc(2026, 7, 10, 12);
            final ids = <int>[];
            late Widget page;
            if (shared) {
              final api = SharedApiClient(
                Uri.parse('https://localhost'),
                MockClient((_) async => http.Response(jsonEncode({}), 404)),
              );
              addTearDown(api.close);
              ids.addAll(List.generate(count, (index) => index + 1));
              page = SharedAnimalsPage(
                api: api,
                boxes: const [
                  {'id': 1, 'name': 'Box', 'status': 'active'},
                ],
                animals: [
                  for (final id in ids)
                    {
                      'id': id,
                      'boxId': 1,
                      'status': 'active',
                      'revision': 'r',
                      'commonName': 'Due $id',
                      'latinName': 'Species',
                      'category': 'other',
                    },
                ],
                reminders: [
                  for (final id in ids)
                    {
                      'animalId': id,
                      'dueAt': DateTime.now()
                          .toUtc()
                          .subtract(const Duration(days: 1))
                          .toIso8601String(),
                    },
                ],
                connected: true,
                change: (_) async => true,
                onReload: () async {},
              );
            } else {
              final database = AppDatabase.test(NativeDatabase.memory());
              addTearDown(database.close);
              final box = await BoxRepository(database).createBox('box');
              for (var i = 0; i < count; i++) {
                ids.add(
                  await AnimalRepository(database).createAnimal(
                    boxId: box,
                    commonName: 'Due ${i + 1}',
                    latinName: 'Species',
                    tempMin: 20,
                    tempMax: 30,
                    humidityMin: 40,
                    humidityMax: 60,
                    feedingReminderIntervalDays: 1,
                    feedingReminderBaseline: now.subtract(
                      const Duration(days: 2),
                    ),
                  ),
                );
              }
              page = AnimalsPage(database: database, reminderNow: () => now);
            }
            final colors =
                ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: brightness,
                ).copyWith(
                  errorContainer: const Color(0xFF204060),
                  onErrorContainer: Colors.white,
                );
            await tester.pumpWidget(
              AppSettingsScope(
                controller: settings,
                child: MaterialApp(
                  theme: ThemeData(
                    colorScheme: colors,
                    dividerColor: Colors.white,
                    dividerTheme: const DividerThemeData(color: Colors.white),
                  ),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: RepaintBoundary(key: _capture, child: page),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final tile = find.byKey(
              PageStorageKey<String>(
                shared
                    ? 'shared-feeding-reminder-summary-toggle'
                    : 'feeding-reminder-summary-toggle',
              ),
            );
            final item = find.byKey(
              Key(
                shared
                    ? 'shared-feeding-reminder-due-${ids.first}'
                    : 'feeding-reminder-summary-item-${ids.first}',
              ),
            );
            expect(item.hitTestable(), findsOneWidget);
            final header = find
                .descendant(of: tile, matching: find.byType(ListTile))
                .first;
            final originalHeader = tester.getRect(header);
            await _checkEdges(tester, tile, '${name}_expanded');
            await tester.tap(find.text('Feeding reminders'));
            await tester.pumpAndSettle();
            expect(item.hitTestable(), findsNothing);
            expect(tester.getRect(header), originalHeader);
            await _checkEdges(tester, tile, '${name}_collapsed');
            await tester.tap(find.text('Feeding reminders'));
            await tester.pumpAndSettle();
            expect(item.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
