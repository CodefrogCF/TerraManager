import 'dart:io';

import 'package:terramanager/shared_server/care_api.dart';
import 'package:terramanager/shared_server/care_authenticator.dart';
import 'package:terramanager/shared_server/server_database.dart';

Future<void> main() async {
  final token = Platform.environment['TM_API_TOKEN'];
  if (token == null || token.length < 32) {
    stderr.writeln('TM_API_TOKEN must contain at least 32 characters.');
    exitCode = 64;
    return;
  }

  final databasePath = Platform.environment['TM_DATABASE_PATH'];
  if (databasePath == null || databasePath.trim().isEmpty) {
    stderr.writeln('TM_DATABASE_PATH must name a persistent SQLite file.');
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
  final database = await openServerDatabase(File(databasePath));
  try {
    final server = await CareApi(
      database: database,
      authenticator: StaticBearerAuthenticator(token),
    ).serve(address: InternetAddress(host), port: port);
    stdout.writeln(
      'TerraManager care API listening on ${server.address.address}:${server.port}',
    );
    stdout.writeln('Configure HTTPS before exposing this listener to the LAN.');
  } catch (_) {
    await database.close();
    rethrow;
  }
}
