import 'dart:io';

import 'package:terramanager/shared_server/account_store.dart';

Future<void> main() async {
  final databasePath = Platform.environment['TM_DATABASE_PATH'];
  if (databasePath == null || databasePath.trim().isEmpty) {
    stderr.writeln('TM_DATABASE_PATH must name the collection SQLite file.');
    exitCode = 64;
    return;
  }
  if (!stdin.hasTerminal) {
    stderr.writeln('Create the administrator from an interactive terminal.');
    exitCode = 64;
    return;
  }
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
    if (accounts.hasAccounts) {
      stderr.writeln('Accounts already exist; initial setup cannot run again.');
      exitCode = 78;
      return;
    }
    stdout.write('Initial administrator username: ');
    final username = stdin.readLineSync() ?? '';
    stdout.write('Password (at least 12 characters): ');
    stdin.echoMode = false;
    final password = stdin.readLineSync() ?? '';
    stdout.writeln();
    stdout.write('Confirm password: ');
    final confirmation = stdin.readLineSync() ?? '';
    stdout.writeln();
    stdin.echoMode = true;
    if (password != confirmation) {
      stderr.writeln('Passwords do not match.');
      exitCode = 64;
      return;
    }
    await accounts.createInitialAdministrator(username, password);
    stdout.writeln('Initial administrator created.');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } finally {
    stdin.echoMode = true;
    accounts.close();
  }
}
