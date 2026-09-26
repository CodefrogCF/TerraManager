import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terramanager/l10n/generated/app_localizations.dart';
import 'package:terramanager/shared_client/navigation/browser_history_port.dart';
import 'package:terramanager/shared_client/navigation/shared_browser_back_observer.dart';
import 'package:terramanager/shared_client/shared_api_client.dart';
import 'package:terramanager/shared_client/shared_box_scanner_page.dart';
import 'package:terramanager/shared_client/shared_detail_pages.dart';

class _History implements BrowserHistoryPort {
  final pushed = <int>[];
  final backed = <int>[];
  final replaced = <int>[];
  bool disposed = false;
  @override
  void initialize(void Function(int depth) onBack) {
    replaced.add(0);
  }

  @override
  void pushDepth(int depth) => pushed.add(depth);
  @override
  void replaceDepth(int depth) => replaced.add(depth);
  @override
  void back(int count) => backed.add(count);
  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  testWidgets(
    'browser Back unwinds real details and scanner without leaving overview',
    (tester) async {
      final history = _History();
      final observer = SharedBrowserBackObserver(history: history);
      final navigator = GlobalKey<NavigatorState>();
      final api = SharedApiClient(
        Uri.parse('https://192.168.1.117'),
        MockClient(
          (_) async => http.Response(
            '{"box":{"id":1,"name":"Box","status":"active"},"animals":[],"pictures":[]}',
            200,
          ),
        ),
      );
      addTearDown(api.close);
      addTearDown(observer.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: Text('Overview')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => SharedBoxDetailPage(
            api: api,
            id: 1,
            boxes: const [],
            animals: const [],
            connected: true,
            change: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(observer.depth, 1);
      expect(history.pushed, [1]);
      await observer.handleBrowserBack(0);
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);
      expect(find.byType(SharedBoxDetailPage), findsNothing);
      expect(history.backed, isEmpty); // Browser already moved; no double Back.

      var stopped = 0;
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => SharedBoxScannerPage(
            api: api,
            boxes: const [],
            animals: const [],
            change: (_) async => true,
            stopScanner: () async {
              stopped++;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(observer.depth, 1);
      await observer.handleBrowserBack(0);
      await tester.pumpAndSettle();
      expect(find.byType(SharedBoxScannerPage), findsNothing);
      expect(find.text('Overview'), findsOneWidget);
      expect(stopped, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'in-app Back synchronizes history and protected dialog keeps its parent',
    (tester) async {
      final history = _History();
      final observer = SharedBrowserBackObserver(history: history);
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(observer.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Overview')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Detail')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(history.backed, [1]);
      await observer.handleBrowserBack(0);
      expect(observer.depth, 0);
      var canLeave = false;
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => PopScope(
            canPop: canLeave,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Keep editing?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Stay'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Scaffold(body: Text('Protected editor')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await observer.handleBrowserBack(0);
      await tester.pumpAndSettle();
      expect(observer.depth, 2);
      expect(history.pushed.sublist(history.pushed.length - 2), [1, 2]);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      await observer.handleBrowserBack(1);
      expect(observer.depth, 1);
      expect(find.text('Protected editor'), findsOneWidget);
      expect(find.text('Keep editing?'), findsNothing);
      canLeave = true;
      // Root overview remains open; a forward event does not reopen old forms.
      await observer.handleBrowserBack(3);
      expect(observer.depth, 1);
      expect(history.replaced.last, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
