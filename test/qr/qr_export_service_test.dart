import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/qr/qr_export_service.dart';

void main() {
  testWidgets('exports QR code as PNG bytes', (tester) async {
    const qrId = 'TM:BOX:12345678-1234-4123-8123-123456789abc';

    final bytes = await tester.runAsync(() {
      return const QrExportService().exportPng(qrId: qrId, size: 256);
    });

    expect(bytes, isNotNull);

    expect(bytes, isA<Uint8List>());

    expect(bytes!, isNotEmpty);

    expect(bytes.take(8).toList(), equals([137, 80, 78, 71, 13, 10, 26, 10]));
  });
}
