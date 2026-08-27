import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../widgets/box_qr_code.dart';

class BoxDetailPage extends StatelessWidget {
  final Box box;

  const BoxDetailPage({
    super.key,
    required this.box,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Box Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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