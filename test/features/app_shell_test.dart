import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/features/navigation/presentation/pages/app_shell.dart';

void main() {
  testWidgets('shows boxes page by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );

    expect(find.text('Boxes'), findsWidgets);
  });

  testWidgets('can navigate to settings', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('can navigate to animals', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );

    await tester.tap(find.text('Animals'));
    await tester.pump();

    expect(find.text('Animal Overview'), findsWidgets);
  });

  testWidgets('can navigate back to boxes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pump();

    await tester.tap(find.text('Boxes'));
    await tester.pump();

    expect(find.text('Box Overview'), findsOneWidget);
  });
}