import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BoxQrCode extends StatelessWidget {
  final String qrId;
  final double size;

  const BoxQrCode({
    super.key,
    required this.qrId,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'QR code for box $qrId',
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: QrImageView(
          key: const Key('box-qr-image'),
          data: qrId,
          version: QrVersions.auto,
          size: size,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}