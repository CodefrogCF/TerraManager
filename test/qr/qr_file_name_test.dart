import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/qr/qr_file_name.dart';

void main() {
  test('builds safe QR PNG file name', () {
    const qrId =
        'TM:BOX:12345678-1234-4123-8123-123456789abc';

    final fileName = buildBoxQrFileName(qrId);

    expect(
      fileName,
      'terramanager_TM_BOX_12345678-1234-4123-8123-123456789abc',
    );
  });

  test('replaces unsafe file name characters', () {
    const qrId = 'TM:BOX:test/value?';

    final fileName = buildBoxQrFileName(qrId);

    expect(
      fileName,
      'terramanager_TM_BOX_test_value_',
    );
  });
}