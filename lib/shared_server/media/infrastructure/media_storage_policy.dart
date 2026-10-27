import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:terramanager/core/database/app_database.dart';

/// The cap applies to stored image bytes, including gallery copies and restores.
/// It is installed only on the Shared Care collection database.
class MediaStoragePolicy {
  const MediaStoragePolicy(this.database);

  static const maxStoredMediaBytes = 512 * 1024 * 1024;
  static const quotaErrorMarker = 'shared_media_quota_exceeded';

  final AppDatabase database;

  // Background Drift isolates stringify SQLite failures. Inspect only the
  // first error line so user-supplied SQL parameters cannot impersonate the
  // trigger marker.
  static bool isQuotaError(Object error) {
    if (error is SqliteException) {
      return error.message.contains(quotaErrorMarker);
    }
    final firstLine = error.toString().split('\n').first;
    return firstLine.startsWith('SqliteException(') &&
        firstLine.contains(quotaErrorMarker);
  }

  Future<void> install({int maxBytes = maxStoredMediaBytes}) async {
    if (maxBytes < 1) throw ArgumentError.value(maxBytes, 'maxBytes');
    await database.transaction(() async {
      await database.customStatement(
        'DROP TRIGGER IF EXISTS shared_media_limit_insert',
      );
      await database.customStatement(
        'DROP TRIGGER IF EXISTS shared_media_limit_update',
      );
      await database.customStatement('''
CREATE TRIGGER shared_media_limit_insert BEFORE INSERT ON media_assets
WHEN (SELECT COALESCE(SUM(LENGTH(data)), 0) FROM media_assets)
     + LENGTH(NEW.data) > $maxBytes
BEGIN SELECT RAISE(ABORT, '$quotaErrorMarker'); END
''');
      await database.customStatement('''
CREATE TRIGGER shared_media_limit_update BEFORE UPDATE OF data ON media_assets
WHEN LENGTH(NEW.data) > LENGTH(OLD.data)
     AND (SELECT COALESCE(SUM(LENGTH(data)), 0) FROM media_assets)
         - LENGTH(OLD.data) + LENGTH(NEW.data) > $maxBytes
BEGIN SELECT RAISE(ABORT, '$quotaErrorMarker'); END
''');
    });
  }

  Future<({int count, int bytes})> unassociatedMedia() async {
    final row = await database.customSelect('''
SELECT COUNT(*) AS media_count, COALESCE(SUM(LENGTH(m.data)), 0) AS byte_count
FROM media_assets AS m WHERE ${_unassociatedPredicate()}
''').getSingle();
    return (
      count: row.read<int>('media_count'),
      bytes: row.read<int>('byte_count'),
    );
  }

  /// Rechecks references and deletes in one transaction. A dry run only reads.
  Future<({int count, int bytes})> cleanUnassociatedMedia() =>
      database.transaction(() async {
        final candidates = await unassociatedMedia();
        await database.customStatement('''
DELETE FROM media_assets WHERE id IN (
  SELECT m.id FROM media_assets AS m WHERE ${_unassociatedPredicate()}
)
''');
        return candidates;
      });

  static String _unassociatedPredicate() => '''
NOT EXISTS (SELECT 1 FROM animal_picture_associations AS a
            WHERE a.media_asset_id = m.id)
AND NOT EXISTS (SELECT 1 FROM box_picture_associations AS b
                WHERE b.media_asset_id = m.id)
AND NOT EXISTS (SELECT 1 FROM animals AS a WHERE a.picture_media_id = m.id)
AND NOT EXISTS (SELECT 1 FROM boxes AS b WHERE b.picture_media_id = m.id)
''';
}
