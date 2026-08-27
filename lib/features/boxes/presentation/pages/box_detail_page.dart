import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/qr/qr_export_service.dart';
import '../../../../core/qr/qr_file_name.dart';
import '../../../../core/qr/qr_storage_service.dart';
import '../widgets/box_qr_code.dart';

class BoxDetailPage extends StatefulWidget {
  final Box box;
  final QrExporter qrExporter;
  final QrStorage qrStorage;

  const BoxDetailPage({
    super.key,
    required this.box,
    this.qrExporter = const QrExportService(),
    this.qrStorage = const QrStorageService(),
  });

  @override
  State<BoxDetailPage> createState() => _BoxDetailPageState();
}

class _BoxDetailPageState extends State<BoxDetailPage> {
  bool _savingQr = false;
  String? _saveError;

  Future<void> _saveQrCode() async {
    setState(() {
      _savingQr = true;
      _saveError = null;
    });

    try {
      final pngBytes = await widget.qrExporter.exportPng(
        qrId: widget.box.qrId,
      );

      final fileName = buildBoxQrFileName(
        widget.box.qrId,
      );

      await widget.qrStorage.savePng(
        bytes: pngBytes,
        fileName: fileName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _savingQr = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code saved'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingQr = false;
        _saveError = 'Failed to save QR code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Box Details'),
        actions: [
          IconButton(
            key: const Key('save-qr-button'),
            onPressed: _savingQr ? null : _saveQrCode,
            icon: _savingQr
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: 'Save QR Code',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_saveError != null) ...[
            Text(
              _saveError!,
              key: const Key('qr-save-error'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
          ],

          Center(
            child: BoxQrCode(
              key: const Key('box-qr-code'),
              qrId: box.qrId,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'QR Identifier',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          SelectableText(
            box.qrId,
            key: const Key('box-qr-id'),
          ),
          const SizedBox(height: 24),

          _DetailRow(
            label: 'Box ID',
            value: box.id.toString(),
          ),

          _DetailRow(
            label: 'Created',
            value: _formatDateTime(box.createdAt),
          ),

          _DetailRow(
            label: 'Updated',
            value: _formatDateTime(box.updatedAt),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}