import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:terramanager/features/boxes/presentation/widgets/box_qr_code.dart';

void main() {
  testWidgets('renders QR code with supplied box QR ID', (tester) async {
    const qrId = 'TM:BOX:12345678-1234-4123-8123-123456789abc';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BoxQrCode(qrId: qrId)),
      ),
    );

    final boxQrCode = tester.widget<BoxQrCode>(find.byType(BoxQrCode));

    expect(boxQrCode.qrId, qrId);

    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('uses supplied QR size', (tester) async {
    const qrId = 'TM:BOX:12345678-1234-4123-8123-123456789abc';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BoxQrCode(qrId: qrId, size: 300)),
      ),
    );

    final boxQrCode = tester.widget<BoxQrCode>(find.byType(BoxQrCode));

    expect(boxQrCode.size, 300);

    expect(find.byType(QrImageView), findsOneWidget);
  });
}
