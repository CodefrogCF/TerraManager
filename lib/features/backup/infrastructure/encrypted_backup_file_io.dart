import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../application/encrypted_backup_container.dart';

/// Authenticates a file-backed envelope without staging a plaintext ZIP. The
/// index contains only frame offsets; at most one decrypted frame is cached.
class EncryptedBackupFile {
  EncryptedBackupFile._(this._file, this._cipher, this._frames, this.length);

  final RandomAccessFile _file;
  final EncryptedBackupCipher _cipher;
  final List<_EncryptedFrame> _frames;
  final int length;
  int _cachedIndex = -1;
  Uint8List _cachedBytes = Uint8List(0);
  bool _closed = false;

  static Future<EncryptedBackupFile> open(
    String path, {
    required String password,
  }) async {
    final file = File(path).openSync(mode: FileMode.read);
    EncryptedBackupCipher? cipher;
    try {
      final fileSize = file.lengthSync();
      if (fileSize < EncryptedBackupContainer.headerLength) {
        throw const EncryptedBackupException(
          EncryptedBackupError.truncated,
          'Encrypted backup header is truncated.',
        );
      }
      final header = Uint8List.fromList(
        file.readSync(EncryptedBackupContainer.headerLength),
      );
      cipher = await EncryptedBackupContainer.openCipher(
        header,
        password: password,
      );
      final frames = <_EncryptedFrame>[];
      var fileOffset = EncryptedBackupContainer.headerLength;
      var plainOffset = 0;
      var index = 0;
      while (true) {
        if (fileOffset + 4 + EncryptedBackupContainer.tagLength > fileSize) {
          throw const EncryptedBackupException(
            EncryptedBackupError.truncated,
            'Encrypted backup is truncated.',
          );
        }
        file.setPositionSync(fileOffset);
        final frameLength = file.readSync(4);
        final size = ByteData.sublistView(Uint8List.fromList(frameLength))
            .getUint32(0, Endian.little);
        if (size > EncryptedBackupContainer.chunkSize) {
          throw const EncryptedBackupException(
            EncryptedBackupError.invalidHeader,
            'Encrypted backup contains an invalid chunk length.',
          );
        }
        final payloadOffset = fileOffset + 4;
        final nextOffset =
            payloadOffset + size + EncryptedBackupContainer.tagLength;
        if (nextOffset > fileSize) {
          throw const EncryptedBackupException(
            EncryptedBackupError.truncated,
            'Encrypted backup is truncated.',
          );
        }
        final ciphertext = Uint8List.fromList(file.readSync(size));
        final tag = Uint8List.fromList(
          file.readSync(EncryptedBackupContainer.tagLength),
        );
        cipher.decryptFrame(index, ciphertext, tag);
        if (size == 0) {
          if (nextOffset != fileSize) {
            throw const EncryptedBackupException(
              EncryptedBackupError.invalidHeader,
              'Encrypted backup has trailing data.',
            );
          }
          return EncryptedBackupFile._(file, cipher, frames, plainOffset);
        }
        frames.add(_EncryptedFrame(payloadOffset, plainOffset, size));
        plainOffset += size;
        fileOffset = nextOffset;
        index++;
      }
    } catch (_) {
      cipher?.dispose();
      file.closeSync();
      rethrow;
    }
  }

  InputStream openZipStream() {
    if (_closed) throw StateError('Encrypted backup file is closed.');
    return _EncryptedBackupInputStream(this, 0, length);
  }

  int _frameFor(int position) {
    var low = 0;
    var high = _frames.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final frame = _frames[mid];
      if (position < frame.plainOffset) {
        high = mid - 1;
      } else if (position >= frame.plainOffset + frame.length) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    throw RangeError.index(position, _frames, 'plaintext position');
  }

  Uint8List _frameBytes(int index) {
    if (_closed) throw StateError('Encrypted backup file is closed.');
    if (_cachedIndex == index) return _cachedBytes;
    final frame = _frames[index];
    _file.setPositionSync(frame.cipherOffset);
    final ciphertext = Uint8List.fromList(_file.readSync(frame.length));
    final tag = Uint8List.fromList(
      _file.readSync(EncryptedBackupContainer.tagLength),
    );
    _cachedBytes.fillRange(0, _cachedBytes.length, 0);
    _cachedBytes = _cipher.decryptFrame(index, ciphertext, tag);
    _cachedIndex = index;
    return _cachedBytes;
  }

  int byteAt(int position) {
    final index = _frameFor(position);
    final frame = _frames[index];
    return _frameBytes(index)[position - frame.plainOffset];
  }

  Uint8List readRange(int position, int count) {
    if (position < 0 || count < 0 || position + count > length) {
      throw RangeError.range(position + count, 0, length);
    }
    final result = Uint8List(count);
    var copied = 0;
    while (copied < count) {
      final index = _frameFor(position + copied);
      final frame = _frames[index];
      final start = position + copied - frame.plainOffset;
      final take = min(count - copied, frame.length - start);
      result.setRange(copied, copied + take, _frameBytes(index), start);
      copied += take;
    }
    return result;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _cachedBytes.fillRange(0, _cachedBytes.length, 0);
    _cipher.dispose();
    _file.closeSync();
  }
}

class _EncryptedFrame {
  const _EncryptedFrame(this.cipherOffset, this.plainOffset, this.length);
  final int cipherOffset;
  final int plainOffset;
  final int length;
}

class _EncryptedBackupInputStream extends InputStream {
  _EncryptedBackupInputStream(this._owner, this._base, this._size)
    : super(byteOrder: ByteOrder.littleEndian);

  final EncryptedBackupFile _owner;
  final int _base;
  final int _size;
  int _position = 0;

  @override
  int get position => _position;
  @override
  set position(int value) => setPosition(value);
  @override
  int get length => _size - _position;
  @override
  bool get isEOS => _position >= _size;
  @override
  bool open() => true;
  @override
  Future<void> close() async {}
  @override
  void closeSync() {}
  @override
  void reset() => _position = 0;
  @override
  void setPosition(int value) {
    _position = value.clamp(0, _size);
  }

  @override
  void rewind([int length = 1]) => setPosition(_position - length);
  @override
  void skip(int length) => setPosition(_position + length);

  @override
  InputStream subset({int? position, int? length, int? bufferSize}) {
    final offset = position ?? _position;
    if (offset < 0 || offset > _size) throw RangeError.range(offset, 0, _size);
    final count = length ?? _size - offset;
    if (count < 0 || offset + count > _size) {
      throw RangeError.range(count, 0, _size - offset);
    }
    return _EncryptedBackupInputStream(_owner, _base + offset, count);
  }

  @override
  int readByte() {
    if (isEOS) return 0;
    return _owner.byteAt(_base + _position++);
  }

  @override
  InputStream readBytes(int count) {
    final size = min(max(count, 0), length);
    final result = subset(position: _position, length: size);
    _position += size;
    return result;
  }

  @override
  Uint8List toUint8List() => _owner.readRange(_base + _position, length);
}
