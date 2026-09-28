import 'dart:io';

import 'package:drift/native.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/media/infrastructure/media_storage_policy.dart';
import 'package:terramanager/shared_server/media/infrastructure/picture_upload_requests.dart';

/// Opens the only writable collection database for a shared server instance.
///
/// The path must be on persistent, local storage owned by the server. Browser
/// clients never receive the file or a SQL connection.
Future<AppDatabase> openServerDatabase(File file) async {
  await file.parent.create(recursive: true);
  final database = AppDatabase(NativeDatabase.createInBackground(file));
  try {
    // Opening Drift here runs all pending schema migrations before the API
    // accepts a request. Existing collection data stays in the same file.
    await database.customSelect('SELECT 1').get();
    await database.customSelect('PRAGMA journal_mode = WAL').get();
    await MediaStoragePolicy(database).install();
    await PictureUploadRequests(database).initialize();
    return database;
  } catch (_) {
    await database.close();
    rethrow;
  }
}
