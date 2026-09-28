import 'dart:io';

import 'package:terramanager/shared_server/media/infrastructure/media_storage_policy.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length > 1 ||
      (arguments.isNotEmpty && arguments.single != '--apply')) {
    stderr.writeln('Usage: cleanup_media [--apply]');
    exitCode = 64;
    return;
  }
  final path = Platform.environment['TM_DATABASE_PATH'];
  if (path == null || path.trim().isEmpty || !await File(path).exists()) {
    stderr.writeln(
      'TM_DATABASE_PATH must name an existing collection database.',
    );
    exitCode = 64;
    return;
  }

  final database = await openServerDatabase(File(path));
  try {
    final policy = MediaStoragePolicy(database);
    final result = arguments.isEmpty
        ? await policy.unassociatedMedia()
        : await policy.cleanUnassociatedMedia();
    stdout.writeln(
      '${arguments.isEmpty ? 'Found' : 'Removed'} '
      '${result.count} unassociated media assets (${result.bytes} bytes).',
    );
  } finally {
    await database.close();
  }
}
