import 'dart:io';

import 'package:terramanager/shared_server/account_store.dart';
import 'package:terramanager/shared_server/server_database.dart';
import 'package:terramanager/shared_server/shared_server_api.dart';

Future<void> main() async {
  final databasePath = Platform.environment['TM_DATABASE_PATH'];
  if (databasePath == null || databasePath.trim().isEmpty) {
    stderr.writeln('TM_DATABASE_PATH must name a persistent SQLite file.');
    exitCode = 64;
    return;
  }

  final originText = Platform.environment['TM_PUBLIC_ORIGIN'];
  final publicUrl = originText == null ? null : Uri.tryParse(originText);
  if (publicUrl == null ||
      publicUrl.userInfo.isNotEmpty ||
      publicUrl.path != '' ||
      publicUrl.query.isNotEmpty ||
      publicUrl.fragment.isNotEmpty) {
    stderr.writeln('TM_PUBLIC_ORIGIN must be the exact public origin.');
    exitCode = 64;
    return;
  }

  final port = int.tryParse(Platform.environment['TM_PORT'] ?? '8080');
  if (port == null || port < 1 || port > 65535) {
    stderr.writeln('TM_PORT must be a valid TCP port.');
    exitCode = 64;
    return;
  }

  final host = Platform.environment['TM_BIND_ADDRESS'] ?? '127.0.0.1';
  final authPath =
      Platform.environment['TM_AUTH_DATABASE_PATH'] ??
      '${File(databasePath).parent.path}${Platform.pathSeparator}accounts.sqlite';
  if (File(authPath).absolute.path.toLowerCase() ==
      File(databasePath).absolute.path.toLowerCase()) {
    stderr.writeln('TM_AUTH_DATABASE_PATH must differ from TM_DATABASE_PATH.');
    exitCode = 64;
    return;
  }
  final accounts = await AccountStore.open(File(authPath));
  try {
    if (!accounts.hasAccounts) {
      stderr.writeln(
        'No accounts exist. Run dart run bin/create_admin.dart first.',
      );
      accounts.close();
      exitCode = 78;
      return;
    }
    final database = await openServerDatabase(File(databasePath));
    try {
      final server = await SharedServerApi(
        database: database,
        accounts: accounts,
        publicUrl: publicUrl,
      ).serve(address: InternetAddress(host), port: port);
      stdout.writeln(
        'TerraManager care API listening on ${server.address.address}:${server.port}',
      );
      stdout.writeln(
        'Configure HTTPS before exposing this listener to the LAN.',
      );
    } catch (_) {
      await database.close();
      rethrow;
    }
  } catch (_) {
    accounts.close();
    rethrow;
  }
}
