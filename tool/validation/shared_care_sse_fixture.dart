// Disposable loopback-only production-API fixture for shared_care_sse_smoke.cjs.
// Never point this tool at production databases or expose it to the LAN.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/app/shared_server_api.dart';
import 'package:terramanager/shared_server/audit/infrastructure/collection_audit_log.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError(
      'Expected public HTTPS origin and compiled adapter JS path.',
    );
  }
  final directory = await Directory.systemTemp.createTemp('tm-sse-smoke-');
  final accounts = await AccountStore.open(
    File('${directory.path}/accounts.sqlite'),
  );
  await accounts.createInitialAdministrator(
    'sse-test-admin',
    'Disposable SSE fixture password 123',
  );
  final database = await openServerDatabase(
    File('${directory.path}/collection.sqlite'),
  );
  await CollectionAuditLog(database).initialize();
  final live = SharedServerApi(
    database: database,
    accounts: accounts,
    publicUrl: Uri.parse(args[0]),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (request.uri.path == '/fixture/stats') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'openStreams': live.changeStreams.activeConnections}),
      );
      await request.response.close();
    } else if (request.uri.path == '/fixture/browser') {
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<!doctype html><title>Disposable SSE transport test</title><script defer src="/fixture/adapter.js"></script>',
      );
      await request.response.close();
    } else if (request.uri.path == '/fixture/adapter.js') {
      request.response.headers.contentType = ContentType('text', 'javascript');
      await request.response.addStream(File(args[1]).openRead());
      await request.response.close();
    } else if (request.uri.path == '/fixture/fragmented' &&
        live.sessions.session(request) != null) {
      request.response.bufferOutput = false;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      // Deliberately split CRLF, field names, JSON and multibyte UTF-8 characters.
      final bytes = utf8.encode(
        ': comment\r\nid: fragment-1\r\nevent: changes\r\ndata: {"note":\r\ndata: "Äö🦎"}\r\n\r\n',
      );
      try {
        for (final byte in bytes) {
          request.response.add([byte]);
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      } catch (_) {
        /* A test may close the source after receiving the frame. */
      }
      await request.response.close();
    } else {
      await live.handle(request);
    }
  });
  stdout.writeln(
    jsonEncode({'port': server.port, 'fixture': 'disposable-production-api'}),
  );
  await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;
  live.changeStreams.close();
  await server.close(force: true);
  while (live.changeStreams.activeConnections != 0) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await database.close();
  accounts.close();
  await directory.delete(recursive: true);
}
