import 'dart:io';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

/// Owns the file-backed databases and temporary directory used by a server test.
///
/// Tests can opt out of either database when they only need one of them. The
/// helper deliberately does not swallow cleanup failures: a persistent open
/// handle is still a test failure, while short Windows file-handle release
/// delays are retried for a bounded amount of time.
class TestDatabaseHelper {
  TestDatabaseHelper._(
    this.directory,
    this.collectionDbFile,
    this.accountsDbFile,
  );

  final Directory directory;
  final File collectionDbFile;
  final File accountsDbFile;

  AppDatabase? _database;
  AccountStore? _accounts;

  AppDatabase get database {
    final value = _database;
    if (value == null) {
      throw StateError('The test collection database is not open.');
    }
    return value;
  }

  AccountStore get accounts {
    final value = _accounts;
    if (value == null) {
      throw StateError('The test account store is not open.');
    }
    return value;
  }

  static Future<TestDatabaseHelper> create({
    String prefix = 'terramanager-test-',
    bool openCollectionDatabase = true,
    bool openAccountStore = true,
  }) async {
    final directory = await Directory.systemTemp.createTemp(prefix);
    final helper = TestDatabaseHelper._(
      directory,
      File('${directory.path}${Platform.pathSeparator}collection.sqlite'),
      File('${directory.path}${Platform.pathSeparator}accounts.sqlite'),
    );

    try {
      if (openCollectionDatabase) {
        helper._database = await openServerDatabase(helper.collectionDbFile);
      }
      if (openAccountStore) {
        helper._accounts = await AccountStore.open(helper.accountsDbFile);
      }
      return helper;
    } catch (_) {
      await helper.cleanup();
      rethrow;
    }
  }

  Future<void> closeCollectionDatabase() async {
    final current = _database;
    _database = null;
    if (current != null) {
      await current.close();
    }
  }

  void closeAccountStore() {
    final current = _accounts;
    _accounts = null;
    current?.close();
  }

  /// Replaces the currently tracked collection database with a freshly opened
  /// instance. When [file] is omitted, the helper's default collection file is
  /// reopened.
  Future<AppDatabase> reopenCollectionDatabase([File? file]) async {
    await closeCollectionDatabase();
    final reopened = await openServerDatabase(file ?? collectionDbFile);
    _database = reopened;
    return reopened;
  }

  Future<void> cleanup() async {
    await closeCollectionDatabase();
    closeAccountStore();
    await _deleteDirectoryWithRetry(directory);
  }

  static Future<void> _deleteDirectoryWithRetry(Directory directory) async {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 25),
      Duration(milliseconds: 50),
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
      Duration(milliseconds: 400),
      Duration(milliseconds: 750),
    ];

    FileSystemException? lastError;
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (!await directory.exists()) return;
      try {
        await directory.delete(recursive: true);
        return;
      } on FileSystemException catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) throw lastError;
  }
}
