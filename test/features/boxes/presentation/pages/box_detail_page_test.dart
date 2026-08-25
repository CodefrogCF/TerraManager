import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/boxes/presentation/pages/box_detail_page.dart';

void main() {
  testWidgets('displays box information', (tester) async {
    final box = Box(
      id: 1,
      qrId: 'test-box-001',
      createdAt: DateTime(2026, 8, 25, 12, 0),
      updatedAt: DateTime(2026, 8, 25, 13, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BoxDetailPage(box: box),
      ),
    );

    expect(find.text('Box Details'), findsOneWidget);
    expect(find.text('test-box-001'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2026-08-25 12:00:00.000'), findsOneWidget);
    expect(find.text('2026-08-25 13:00:00.000'), findsOneWidget);
  });
}