import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class PasswordHasher {
  static final _passwordAlgorithm = Argon2id(
    memory: 19456,
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
  );

  static Future<String> hash(String password, List<int> salt) async {
    final key = await _passwordAlgorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return 'argon2id\$v=19\$m=19456,t=2,p=1\$${base64Url.encode(salt)}\$${base64Url.encode(bytes)}';
  }

  static Future<bool> verify(String password, String encoded) async {
    final fields = encoded.split(r'$');
    if (fields.length != 5 ||
        fields[0] != 'argon2id' ||
        fields[1] != 'v=19' ||
        fields[2] != 'm=19456,t=2,p=1') {
      return false;
    }
    final candidate = await hash(password, base64Url.decode(fields[3]));
    final left = utf8.encode(candidate);
    final right = utf8.encode(encoded);
    var difference = left.length ^ right.length;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ (i < right.length ? right[i] : 0);
    }
    return difference == 0;
  }

  static const dummyHash =
      'argon2id\$v=19\$m=19456,t=2,p=1\$AAAAAAAAAAAAAAAAAAAAAA==\$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
}
