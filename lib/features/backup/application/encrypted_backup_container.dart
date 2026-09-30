import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// An authenticated, versioned envelope around an unchanged portable ZIP.
abstract final class EncryptedBackupContainer {
  static final Uint8List magic = Uint8List.fromList(ascii.encode('TMBKENC!'));
  static const int version = 1;
  static const int headerLength = 42;
  static const int chunkSize = 256 * 1024;
  static const int tagLength = 16;
  static const int kdfMemoryKiB = 19456;
  static const int kdfIterations = 2;
  static const int kdfParallelism = 1;

  /// A partial magic prefix is a damaged encrypted file, not a legacy ZIP.
  static bool hasEncryptedHeader(List<int> prefix) {
    final count = min(prefix.length, magic.length);
    for (var i = 0; i < count; i++) {
      if (prefix[i] != magic[i]) return false;
    }
    if (count < magic.length) {
      throw const EncryptedBackupException(
        EncryptedBackupError.truncated,
        'Encrypted backup header is truncated.',
      );
    }
    return true;
  }

  static Future<EncryptedBackupOutputStream> newOutput(
    OutputStream destination, {
    required String password,
    Random? random,
  }) async {
    if (password.isEmpty) throw ArgumentError.value(password, 'password');
    final secureRandom = random ?? Random.secure();
    final header = Uint8List(headerLength);
    header.setRange(0, magic.length, magic);
    header[8] = version;
    header[9] = 1; // Argon2id
    header[10] = 1; // AES-256-GCM
    final fields = ByteData.sublistView(header);
    fields.setUint32(11, chunkSize, Endian.little);
    fields.setUint32(15, kdfMemoryKiB, Endian.little);
    fields.setUint16(19, kdfIterations, Endian.little);
    header[21] = kdfParallelism;
    for (var i = 22; i < headerLength; i++) {
      header[i] = secureRandom.nextInt(256);
    }
    final key = await _deriveKey(password, header);
    destination.writeBytes(header);
    return EncryptedBackupOutputStream._(destination, header, key);
  }

  static Future<Uint8List> encryptBytes(
    Uint8List input, {
    required String password,
  }) async {
    final output = OutputMemoryStream();
    final encrypted = await newOutput(output, password: password);
    try {
      encrypted.writeBytes(input);
      encrypted.finish();
      return output.getBytes();
    } finally {
      encrypted.dispose();
    }
  }

  /// Encrypts a downloaded ZIP with bounded buffering for browser saves.
  static Stream<Uint8List> encryptStream(
    Stream<List<int>> input, {
    required String password,
  }) async* {
    final destination = _ChunkOutputStream();
    final encrypted = await newOutput(destination, password: password);
    try {
      yield destination.take();
      await for (final chunk in input) {
        for (var offset = 0; offset < chunk.length; offset += chunkSize) {
          final end = min(offset + chunkSize, chunk.length);
          encrypted.writeBytes(chunk.sublist(offset, end));
          if (destination.hasBytes) yield destination.take();
        }
      }
      encrypted.finish();
      if (destination.hasBytes) yield destination.take();
    } finally {
      encrypted.dispose();
    }
  }

  static Future<Uint8List> decryptBytes(
    Uint8List input, {
    required String password,
  }) async {
    final output = BytesBuilder(copy: false);
    await for (final chunk in decryptStream(
      Stream.value(input),
      password: password,
    )) {
      output.add(chunk);
    }
    return output.takeBytes();
  }

  /// For file-backed readers that authenticate every frame before exposing
  /// the ZIP and then need bounded, random-access reads.
  static Future<EncryptedBackupCipher> openCipher(
    Uint8List header, {
    required String password,
  }) async {
    if (header.length != headerLength || !hasEncryptedHeader(header)) {
      throw const EncryptedBackupException(
        EncryptedBackupError.truncated,
        'Encrypted backup header is truncated.',
      );
    }
    _validateHeader(header);
    return EncryptedBackupCipher._(
      Uint8List.fromList(header),
      await _deriveKey(password, header),
    );
  }

  /// Each yielded chunk is authenticated. Callers must wait for the final
  /// authenticated frame before displaying data or replacing a collection.
  static Stream<Uint8List> decryptStream(
    Stream<List<int>> input, {
    required String password,
  }) async* {
    final reader = _ExactByteReader(input);
    SecretKeyData? key;
    try {
      final magicBytes = await reader.read(magic.length);
      if (!hasEncryptedHeader(magicBytes)) {
        throw const EncryptedBackupException(
          EncryptedBackupError.invalidHeader,
          'This is not an encrypted TerraManager backup.',
        );
      }
      final tail = await reader.read(headerLength - magic.length);
      final header = Uint8List(headerLength)
        ..setRange(0, magic.length, magicBytes)
        ..setRange(magic.length, headerLength, tail);
      _validateHeader(header);
      key = await _deriveKey(password, header);
      final cipher = DartAesGcm.with256bits();
      var index = 0;
      while (true) {
        final frameLength = await reader.read(4);
        final size = ByteData.sublistView(frameLength)
            .getUint32(0, Endian.little);
        if (size > chunkSize) {
          throw const EncryptedBackupException(
            EncryptedBackupError.invalidHeader,
            'Encrypted backup contains an invalid chunk length.',
          );
        }
        final ciphertext = await reader.read(size);
        final tag = await reader.read(tagLength);
        final List<int> plaintext;
        try {
          plaintext = cipher.decryptSync(
            SecretBox(ciphertext, nonce: _nonce(header, index), mac: Mac(tag)),
            secretKeyData: key,
            aad: _aad(header, index, size),
          );
        } on SecretBoxAuthenticationError {
          throw const EncryptedBackupException(
            EncryptedBackupError.authenticationFailed,
            'Incorrect password or modified/damaged backup.',
          );
        }
        index++;
        if (size == 0) break;
        yield Uint8List.fromList(plaintext);
      }
      if (await reader.hasMore) {
        throw const EncryptedBackupException(
          EncryptedBackupError.invalidHeader,
          'Encrypted backup has trailing data.',
        );
      }
    } finally {
      key?.destroy();
      await reader.cancel();
    }
  }

  static void _validateHeader(Uint8List header) {
    if (header[8] != version) {
      throw const EncryptedBackupException(
        EncryptedBackupError.unsupportedVersion,
        'Unsupported encrypted backup container version.',
      );
    }
    final fields = ByteData.sublistView(header);
    final blockSize = fields.getUint32(11, Endian.little);
    final memory = fields.getUint32(15, Endian.little);
    final iterations = fields.getUint16(19, Endian.little);
    final parallelism = header[21];
    if (header[9] != 1 ||
        header[10] != 1 ||
        blockSize != chunkSize ||
        memory < kdfMemoryKiB ||
        memory > 65536 ||
        iterations < kdfIterations ||
        iterations > 8 ||
        parallelism < 1 ||
        parallelism > 4) {
      throw const EncryptedBackupException(
        EncryptedBackupError.invalidHeader,
        'Encrypted backup header contains unsupported parameters.',
      );
    }
  }

  static Future<SecretKeyData> _deriveKey(
    String password,
    Uint8List header,
  ) async {
    final fields = ByteData.sublistView(header);
    final kdf = Argon2id(
      memory: fields.getUint32(15, Endian.little),
      iterations: fields.getUint16(19, Endian.little),
      parallelism: header[21],
      hashLength: 32,
    );
    final secret = await kdf.deriveKeyFromPassword(
      password: password,
      nonce: header.sublist(22, 38),
    );
    return SecretKeyData(await secret.extractBytes());
  }

  static Uint8List _nonce(Uint8List header, int index) {
    final nonce = Uint8List(12);
    nonce.setRange(0, 4, header, 38);
    ByteData.sublistView(nonce).setUint64(4, index, Endian.big);
    return nonce;
  }

  static Uint8List _aad(Uint8List header, int index, int length) {
    final aad = Uint8List(headerLength + 12);
    aad.setRange(0, headerLength, header);
    final fields = ByteData.sublistView(aad);
    fields.setUint64(headerLength, index, Endian.big);
    fields.setUint32(headerLength + 8, length, Endian.little);
    return aad;
  }
}

enum EncryptedBackupError {
  invalidHeader,
  unsupportedVersion,
  truncated,
  authenticationFailed,
}

class EncryptedBackupException implements Exception {
  const EncryptedBackupException(this.code, this.message);
  final EncryptedBackupError code;
  final String message;
  @override
  String toString() => message;
}

class EncryptedBackupCipher {
  EncryptedBackupCipher._(this._header, this._key);
  final Uint8List _header;
  final SecretKeyData _key;
  final DartAesGcm _cipher = DartAesGcm.with256bits();
  bool _disposed = false;

  Uint8List decryptFrame(int index, Uint8List ciphertext, Uint8List tag) {
    if (_disposed) throw StateError('Encrypted backup cipher is disposed.');
    if (ciphertext.length > EncryptedBackupContainer.chunkSize ||
        tag.length != EncryptedBackupContainer.tagLength) {
      throw const EncryptedBackupException(
        EncryptedBackupError.invalidHeader,
        'Encrypted backup contains an invalid frame.',
      );
    }
    try {
      return Uint8List.fromList(
        _cipher.decryptSync(
          SecretBox(
            ciphertext,
            nonce: EncryptedBackupContainer._nonce(_header, index),
            mac: Mac(tag),
          ),
          secretKeyData: _key,
          aad: EncryptedBackupContainer._aad(_header, index, ciphertext.length),
        ),
      );
    } on SecretBoxAuthenticationError {
      throw const EncryptedBackupException(
        EncryptedBackupError.authenticationFailed,
        'Incorrect password or modified/damaged backup.',
      );
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _key.destroy();
  }
}

/// ZIP bytes are encrypted before they reach the caller's destination.
class EncryptedBackupOutputStream extends OutputStream {
  EncryptedBackupOutputStream._(this._destination, this._header, this._key)
    : super(byteOrder: ByteOrder.littleEndian);

  final OutputStream _destination;
  final Uint8List _header;
  final SecretKeyData _key;
  final DartAesGcm _cipher = DartAesGcm.with256bits();
  final Uint8List _pending = Uint8List(EncryptedBackupContainer.chunkSize);
  int _pendingLength = 0;
  int _length = 0;
  int _index = 0;
  bool _finished = false;
  bool _disposed = false;

  @override
  int get length => _length;

  @override
  bool get isOpen => !_finished;

  @override
  void writeByte(int value) => writeBytes([value]);

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    if (_finished || _disposed) throw StateError('Encrypted backup is closed.');
    final count = length ?? bytes.length;
    if (count < 0 || count > bytes.length) {
      throw RangeError.range(count, 0, bytes.length);
    }
    var offset = 0;
    while (offset < count) {
      final take = min(
        EncryptedBackupContainer.chunkSize - _pendingLength,
        count - offset,
      );
      _pending.setRange(_pendingLength, _pendingLength + take, bytes, offset);
      _pendingLength += take;
      _length += take;
      offset += take;
      if (_pendingLength == EncryptedBackupContainer.chunkSize) _writeFrame();
    }
  }

  @override
  void writeStream(InputStream stream) {
    while (!stream.isEOS) {
      writeBytes(
        stream
            .readBytes(min(stream.length, EncryptedBackupContainer.chunkSize))
            .toUint8List(),
      );
    }
  }

  void _writeFrame() {
    final box = _cipher.encryptSync(
      Uint8List.sublistView(_pending, 0, _pendingLength),
      secretKeyData: _key,
      nonce: EncryptedBackupContainer._nonce(_header, _index),
      aad: EncryptedBackupContainer._aad(_header, _index, _pendingLength),
    );
    final frameLength = ByteData(4)
      ..setUint32(0, _pendingLength, Endian.little);
    _destination.writeBytes(frameLength.buffer.asUint8List());
    _destination.writeBytes(box.cipherText);
    _destination.writeBytes(box.mac.bytes);
    _index++;
    _pendingLength = 0;
  }

  @override
  void flush() {
    if (_pendingLength > 0) _writeFrame();
    _destination.flush();
  }

  void finish() {
    if (_finished || _disposed) throw StateError('Encrypted backup is closed.');
    flush();
    _writeFrame(); // Authenticated empty terminator detects truncation.
    _finished = true;
    _destination.flush();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending.fillRange(0, _pending.length, 0);
    _key.destroy();
  }

  @override
  Future<void> close() async {
    if (!_finished) finish();
    dispose();
  }

  @override
  void closeSync() {
    if (!_finished) finish();
    dispose();
  }

  @override
  void clear() => throw UnsupportedError('Encrypted output cannot be cleared.');

  @override
  Uint8List subset(int start, [int? end]) =>
      throw UnsupportedError('Encrypted output cannot be read.');
}

class _ExactByteReader {
  _ExactByteReader(Stream<List<int>> source)
    : _iterator = StreamIterator(source);
  final StreamIterator<List<int>> _iterator;
  List<int> _current = const [];
  int _offset = 0;

  Future<Uint8List> read(int count) async {
    final result = Uint8List(count);
    var written = 0;
    while (written < count) {
      if (_offset == _current.length) {
        if (!await _iterator.moveNext()) {
          throw const EncryptedBackupException(
            EncryptedBackupError.truncated,
            'Encrypted backup is truncated.',
          );
        }
        _current = _iterator.current;
        _offset = 0;
        if (_current.isEmpty) continue;
      }
      final take = min(count - written, _current.length - _offset);
      result.setRange(written, written + take, _current, _offset);
      _offset += take;
      written += take;
    }
    return result;
  }

  Future<bool> get hasMore async {
    if (_offset < _current.length) return true;
    while (await _iterator.moveNext()) {
      if (_iterator.current.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> cancel() => _iterator.cancel();
}

class _ChunkOutputStream extends OutputStream {
  _ChunkOutputStream() : super(byteOrder: ByteOrder.littleEndian);
  BytesBuilder _buffer = BytesBuilder(copy: false);
  int _length = 0;
  @override
  int get length => _length;
  @override
  bool get isOpen => true;
  bool get hasBytes => _buffer.length > 0;
  Uint8List take() {
    final bytes = _buffer.takeBytes();
    _buffer = BytesBuilder(copy: false);
    return bytes;
  }

  @override
  void writeByte(int value) => writeBytes([value]);
  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    _buffer.add(bytes.take(count).toList());
    _length += count;
  }

  @override
  void writeStream(InputStream stream) {
    writeBytes(stream.toUint8List());
  }

  @override
  void flush() {}
  @override
  void clear() => throw UnsupportedError('Cannot clear streamed output.');
  @override
  Uint8List subset(int start, [int? end]) =>
      throw UnsupportedError('Cannot read streamed output.');
}
