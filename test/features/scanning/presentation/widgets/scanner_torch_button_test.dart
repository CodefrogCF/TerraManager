import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:terramanager/features/scanning/presentation/widgets/scanner_torch_button.dart';

void main() {
  const buttonKey = Key('test-scanner-torch-button');

  Widget buildButton({
    required TorchState torchState,
    required Future<void> Function() onToggle,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ScannerTorchButton(
          torchState: torchState,
          onToggle: onToggle,
          buttonKey: buttonKey,
        ),
      ),
    );
  }

  testWidgets('hides the control when the camera has no torch', (tester) async {
    await tester.pumpWidget(
      buildButton(torchState: TorchState.unavailable, onToggle: () async {}),
    );

    expect(find.byKey(buttonKey), findsNothing);
  });

  testWidgets('offers to turn an inactive camera light on', (tester) async {
    var toggleCalls = 0;

    await tester.pumpWidget(
      buildButton(
        torchState: TorchState.off,
        onToggle: () async {
          toggleCalls++;
        },
      ),
    );

    expect(find.byTooltip('Turn camera light on'), findsOneWidget);
    expect(find.byIcon(Icons.flashlight_on), findsOneWidget);

    await tester.tap(find.byKey(buttonKey));
    await tester.pump();

    expect(toggleCalls, 1);
  });

  for (final torchState in [TorchState.on, TorchState.auto]) {
    testWidgets('offers to turn an active $torchState camera light off', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildButton(torchState: torchState, onToggle: () async {}),
      );

      expect(find.byTooltip('Turn camera light off'), findsOneWidget);
      expect(find.byIcon(Icons.flashlight_off), findsOneWidget);
    });
  }

  testWidgets('reports a camera-light failure without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildButton(
        torchState: TorchState.off,
        onToggle: () async {
          throw StateError('Camera light failed');
        },
      ),
    );

    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();

    expect(find.text('Failed to change camera light'), findsOneWidget);
  });
}
