import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../l10n/app_localizations_context.dart';

class ScannerTorchButton extends StatefulWidget {
  final TorchState torchState;
  final Future<void> Function() onToggle;
  final Key buttonKey;

  const ScannerTorchButton({
    super.key,
    required this.torchState,
    required this.onToggle,
    required this.buttonKey,
  });

  @override
  State<ScannerTorchButton> createState() => _ScannerTorchButtonState();
}

class _ScannerTorchButtonState extends State<ScannerTorchButton> {
  bool _isToggling = false;

  Future<void> _toggleTorch() async {
    if (_isToggling) {
      return;
    }

    setState(() {
      _isToggling = true;
    });

    try {
      await widget.onToggle();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failedToToggleCameraLight)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.torchState == TorchState.unavailable) {
      return const SizedBox.shrink();
    }

    final isOn =
        widget.torchState == TorchState.on ||
        widget.torchState == TorchState.auto;

    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        key: widget.buttonKey,
        tooltip: isOn
            ? context.l10n.turnOffCameraLight
            : context.l10n.turnOnCameraLight,
        onPressed: _isToggling ? null : _toggleTorch,
        icon: Icon(
          isOn ? Icons.flashlight_off : Icons.flashlight_on,
          color: Colors.white,
        ),
      ),
    );
  }
}
