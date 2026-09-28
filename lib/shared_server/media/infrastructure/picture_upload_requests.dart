import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:terramanager/core/database/app_database.dart';

/// Server-only upload receipts. They commit with the picture and are excluded
/// from portable collection backups.
class PictureUploadRequests {
  const PictureUploadRequests(this.database);

  static const retention = Duration(days: 30);
  final AppDatabase database;

  Future<void> initialize() async {
    await database.customStatement('''
CREATE TABLE IF NOT EXISTS shared_picture_upload_requests (
  request_key TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  record_id INTEGER NOT NULL,
  payload_hash TEXT NOT NULL,
  media_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL
)
''');
    await database.customStatement('''
CREATE INDEX IF NOT EXISTS shared_picture_upload_time
ON shared_picture_upload_requests(created_at)
''');
    await prune();
  }

  Future<void> prune() => database.customStatement(
    'DELETE FROM shared_picture_upload_requests WHERE created_at < ?',
    [DateTime.now().toUtc().subtract(retention).millisecondsSinceEpoch],
  );

  Future<({String kind, int recordId, String payloadHash, int mediaId})?> find(
    String key,
  ) async {
    final row = await database
        .customSelect(
          'SELECT kind, record_id, payload_hash, media_id '
          'FROM shared_picture_upload_requests WHERE request_key = ?',
          variables: [Variable(key)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (
      kind: row.read<String>('kind'),
      recordId: row.read<int>('record_id'),
      payloadHash: row.read<String>('payload_hash'),
      mediaId: row.read<int>('media_id'),
    );
  }

  Future<void> remember({
    required String key,
    required String kind,
    required int recordId,
    required String payloadHash,
    required int mediaId,
  }) => database.customStatement(
    'INSERT INTO shared_picture_upload_requests '
    '(request_key, kind, record_id, payload_hash, media_id, created_at) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    [
      key,
      kind,
      recordId,
      payloadHash,
      mediaId,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    ],
  );

  Future<void> clear() =>
      database.customStatement('DELETE FROM shared_picture_upload_requests');

  static String fingerprint({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required DateTime? capturedAt,
    required bool makePrimary,
  }) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'fileName': fileName,
            'mimeType': mimeType,
            'dataSha256': sha256.convert(bytes).toString(),
            'capturedAt': capturedAt?.toUtc().toIso8601String(),
            'makePrimary': makePrimary,
          }),
        ),
      )
      .toString();
}
