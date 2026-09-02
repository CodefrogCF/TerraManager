import 'package:flutter_test/flutter_test.dart';

import 'package:terramanager/core/qr/qr_validator.dart';

void main() {
  test('accepts valid TerraManager box QR ID', () {
    expect(
      isValidBoxQrId('TM:BOX:12345678-1234-4123-8123-123456789abc'),
      isTrue,
    );
  });

  test('rejects unrelated QR content', () {
    expect(isValidBoxQrId('https://example.com'), isFalse);

    expect(isValidBoxQrId('hello'), isFalse);
  });

  test('rejects malformed TerraManager QR ID', () {
    expect(isValidBoxQrId('TM:BOX:not-a-uuid'), isFalse);
  });

  test('rejects non-v4 UUID', () {
    expect(
      isValidBoxQrId('TM:BOX:12345678-1234-5123-8123-123456789abc'),
      isFalse,
    );
  });
}
