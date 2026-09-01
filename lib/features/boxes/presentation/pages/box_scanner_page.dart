import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/box_repository.dart';
import '../../../../core/qr/qr_validator.dart';
import 'box_detail_page.dart';

class BoxScannerPage extends StatefulWidget {
  final AppDatabase database;

  final void Function(
    Future<void> Function(String value) handler,
  )? onHandlerReady;

  final Future<void> Function()? stopScanner;
  final Future<void> Function()? startScanner;

  const BoxScannerPage({
    super.key,
    required this.database,
    this.onHandlerReady,
    this.stopScanner,
    this.startScanner,
  });

  @override
  State<BoxScannerPage> createState() => _BoxScannerPageState();
}

class _BoxScannerPageState extends State<BoxScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.qrCode,
    ],
  );

  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onHandlerReady?.call(_handleQrValue);
    });
  }

  Future<void> _stopScanner() async {
    if (widget.stopScanner != null) {
      await widget.stopScanner!();
      return;
    }

    await _controller.stop();
  }

  Future<void> _startScanner() async {
    if (widget.startScanner != null) {
      await widget.startScanner!();
      return;
    }

    await _controller.start();
  }

  Future<void> _handleQrValue(String value) async {
    if (_processing) {
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    if (!isValidBoxQrId(value)) {
      setState(() {
        _processing = false;
        _error = 'Invalid TerraManager QR code';
      });
      return;
    }

    try {
      final box = await BoxRepository(
        widget.database,
      ).getBoxByQrId(value);

      if (!mounted) {
        return;
      }

      if (box == null) {
        setState(() {
          _processing = false;
          _error = 'Box not found';
        });
        return;
      }

      await _stopScanner();

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BoxDetailPage(
            database: widget.database,
            box: box,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _processing = false;
      });

      await _startScanner();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processing = false;
        _error = 'Failed to scan QR code';
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing || capture.barcodes.isEmpty) {
      return;
    }

    final value = capture.barcodes.first.rawValue;

    if (value == null || value.trim().isEmpty) {
      return;
    }

    _handleQrValue(
      value.trim(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Box'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  key: const Key('box-qr-scanner'),
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Text(
                        'Camera unavailable',
                        key: const Key('scanner-camera-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  },
                ),

                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                if (_processing)
                  const Center(
                    child: CircularProgressIndicator(
                      key: Key('scanner-progress'),
                    ),
                  ),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                key: const Key('scanner-error'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}