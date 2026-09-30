import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../domain/backup_data.dart';
import '../domain/backup_format.dart';
import '../domain/backup_manifest.dart';
import '../domain/backup_settings.dart';

/// Adds each picture to the ZIP as it is read. The caller chooses whether the
/// ZIP output is kept in memory or written to another [OutputStream].
class BackupZipBuilder {
  BackupZipBuilder(this._output) {
    _encoder.startEncode(_output);
  }

  final ZipEncoder _encoder = ZipEncoder();
  final OutputStream _output;
  final Set<String> _mediaPaths = <String>{};
  bool _finished = false;

  int get mediaFileCount => _mediaPaths.length;

  void addMedia(String path, Uint8List bytes) {
    if (_finished) {
      throw StateError('Backup ZIP is already complete.');
    }
    if (!_mediaPaths.add(path)) {
      throw StateError('Duplicate backup media path: $path');
    }
    _encoder.add(ArchiveFile.bytes(path, bytes));
  }

  void finish({
    required BackupManifest manifest,
    required BackupData data,
    required BackupSettings settings,
  }) {
    if (_finished) {
      throw StateError('Backup ZIP is already complete.');
    }
    _finished = true;
    const jsonEncoder = JsonEncoder.withIndent('  ');
    _encoder.add(
      ArchiveFile.string(
        BackupFormat.manifestFileName,
        jsonEncoder.convert(manifest.toJson()),
      ),
    );
    _encoder.add(
      ArchiveFile.string(
        BackupFormat.dataFileName,
        jsonEncoder.convert(data.toJson()),
      ),
    );
    _encoder.add(
      ArchiveFile.string(
        BackupFormat.settingsFileName,
        jsonEncoder.convert(settings.toJson()),
      ),
    );
    _encoder.endEncode();
  }
}
