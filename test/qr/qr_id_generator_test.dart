import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/qr/qr_id_generator.dart';

void main() {
  test('generates box QR ID with expected format', () {
    final qrId = generateBoxQrId();

    expect(
      qrId,
      matches(
        RegExp(
          r'^TM:BOX:'
          r'[0-9a-f]{8}-'
          r'[0-9a-f]{4}-'
          r'4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('generates different QR IDs', () {
    final first = generateBoxQrId();
    final second = generateBoxQrId();

    expect(first, isNot(second));
  });
}
