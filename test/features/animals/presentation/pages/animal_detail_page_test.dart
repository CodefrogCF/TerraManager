import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/animals/presentation/pages/animal_detail_page.dart';

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

  testWidgets('shows animal details', (tester) async {
    await database.into(database.boxes).insert(
          BoxesCompanion.insert(
            qrId: 'test-box-001',
          ),
        );

    final animalId = await database.into(database.animals).insert(
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
        home: AnimalDetailPage(
          database: database,
          animalId: animalId,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Kornnatter'), findsOneWidget);
    expect(find.text('Pantherophis guttatus'), findsOneWidget);
    expect(find.text('24.0 °C – 28.0 °C'), findsOneWidget);
    expect(find.text('40.0% – 60.0%'), findsOneWidget);
  });

  testWidgets('shows not found state for missing animal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnimalDetailPage(
          database: database,
          animalId: 999,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Animal not found'), findsOneWidget);
  });
}