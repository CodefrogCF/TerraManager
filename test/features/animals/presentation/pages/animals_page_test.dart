import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/animals/presentation/pages/animals_page.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(
      NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('shows animals from database', (tester) async {
    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: 1,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            tempMin: 24,
            tempMax: 28,
            humidityMin: 40,
            humidityMax: 60,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalsPage(database: database),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Kornnatter'), findsOneWidget);
    expect(find.text('Pantherophis guttatus'), findsOneWidget);
  });

  testWidgets('shows empty state when no animals exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnimalsPage(database: database),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No animals available'), findsOneWidget);
  });

  testWidgets('navigates to animal detail page when an animal is tapped', (tester) async {
    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    await database.into(database.animals).insert(
          AnimalsCompanion.insert(
            boxId: 1,
            commonName: 'Kornnatter',
            latinName: 'Pantherophis guttatus',
            tempMin: 24,
            tempMax: 28,
            humidityMin: 40,
            humidityMax: 60,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimalsPage(database: database),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Kornnatter'));
    await tester.pumpAndSettle();

    expect(find.text('Animal Details'), findsOneWidget);
    expect(find.text('Pantherophis guttatus'), findsOneWidget);
  });
}