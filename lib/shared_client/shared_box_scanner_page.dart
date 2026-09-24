import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/qr/qr_validator.dart';
import '../l10n/app_localizations_context.dart';
import 'shared_api_client.dart';
import 'shared_collection_pages.dart';
import 'shared_detail_pages.dart';
import 'shared_text.dart';

/// Scans a Box label locally and resolves only its identifier through the
/// authenticated, same-origin care API. Camera frames never leave the browser.
class SharedBoxScannerPage extends StatefulWidget {
  const SharedBoxScannerPage({
    super.key,
    required this.api,
    required this.boxes,
    required this.animals,
    required this.change,
    this.onHandlerReady,
    this.stopScanner,
    this.startScanner,
  });

  final SharedApiClient api;
  final List<Map<String, dynamic>> boxes;
  final List<Map<String, dynamic>> animals;
  final SharedChange change;

  final void Function(Future<void> Function(String value) handler)?
  onHandlerReady;
  final Future<void> Function()? stopScanner;
  final Future<void> Function()? startScanner;

  @override
  State<SharedBoxScannerPage> createState() => _SharedBoxScannerPageState();
}

class _SharedBoxScannerPageState extends State<SharedBoxScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
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

  Future<void> _stopScanner() =>
      widget.stopScanner?.call() ?? _controller.stop();

  Future<void> _startScanner() =>
      widget.startScanner?.call() ?? _controller.start();

  Future<void> _handleQrValue(String value) async {
    if (_processing || !mounted) return;
    final qrId = value.trim();
    if (!isValidBoxQrId(qrId)) {
      setState(() => _error = context.l10n.invalidTerraManagerQrCode);
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final box = await widget.api.boxByQrId(qrId);
      if (!mounted) return;
      if (box['status'] == 'archived') {
        setState(() => _error = context.l10n.archivedBoxScanned);
        return;
      }
      if (box['status'] != 'active' || box['id'] is! int) {
        setState(() => _error = context.l10n.failedToScanQrCode);
        return;
      }

      await _stopScanner();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SharedBoxDetailPage(
            api: widget.api,
            id: box['id'] as int,
            boxes: widget.boxes,
            animals: widget.animals,
            connected: widget.api.connected,
            change: widget.change,
          ),
        ),
      );
      if (!mounted) return;
      await _startScanner();
    } on SharedApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.status == 404
            ? context.l10n.boxNotFound
            : context.l10n.failedToScanQrCode;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.failedToScanQrCode);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;
    _handleQrValue(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.scanBoxTitle)),
    body: Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                key: const Key('shared-box-qr-scanner'),
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      sharedText(
                        context,
                        'Camera or browser QR recognition is unavailable. Allow camera access in a supported browser.',
                        'Kamera oder QR-Erkennung des Browsers nicht verfügbar. Erlaube den Kamerazugriff in einem unterstützten Browser.',
                      ),
                      key: const Key('shared-scanner-camera-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (_processing)
                const Center(
                  child: CircularProgressIndicator(
                    key: Key('shared-scanner-progress'),
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
              key: const Key('shared-scanner-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );
}
