import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/features/feedings/presentation/widgets/feeding_due_date_label.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows scheduled wall time without a zone suffix', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Text(
                  feedingDueDateLabel(
                    context,
                    DateTime.utc(2026, 6, 1, 16),
                    timeZone: 'Europe/Berlin',
                  ),
                ),
                Text(
                  feedingDueDateLabel(
                    context,
                    DateTime.utc(2026, 1, 5, 17),
                    timeZone: 'Europe/Berlin',
                  ),
                ),
                Text(
                  feedingDueDateLabel(
                    context,
                    DateTime.utc(2026, 6, 1, 16),
                    timeZone: 'America/New_York',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('18:00'), findsNWidgets(2));
    expect(find.textContaining('12:00'), findsOneWidget);
    expect(find.textContaining('Europe/Berlin'), findsNothing);
    expect(find.textContaining('America/New_York'), findsNothing);
  });
}
