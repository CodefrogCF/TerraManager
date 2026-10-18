/// Disposable evaluation entry point. Never imported by the production server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/app/shared_server_api.dart';
import 'package:terramanager/shared_server/audit/infrastructure/collection_audit_log.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/http/session_authenticator.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/infrastructure/database/server_database.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_response.dart';

import 'change_feed.dart';

class UpdateEvaluationLab {
  UpdateEvaluationLab._(
    this.server,
    this.directory,
    this.database,
    this.accounts,
    this.api,
    this.sessions,
    this.assets,
    this.fixture,
    this.integrated,
    this.fixtureId,
  );

  final HttpServer server;
  final Directory directory;
  final AppDatabase database;
  final AccountStore accounts;
  final SharedServerApi api;
  final SessionAuthenticator sessions;
  final Directory assets;
  final Map<String, int> fixture;
  final bool integrated;
  final String fixtureId;
  final feed = EvaluationChangeFeed();
  final Map<String, int> requests = {};
  final Set<Future<void> Function()> _disconnect = {};
  bool _closed = false;
  int _streams = 0;

  static Future<UpdateEvaluationLab> start({
    required Directory scratchParent,
    required Directory assets,
    int animalCount = 100,
    int historyPerAnimal = 20,
    String bind = '127.0.0.1',
    int port = 0,
    Uri? publicOrigin,
    bool integrated = false,
  }) async {
    if (animalCount < 1 ||
        animalCount > 10000 ||
        historyPerAnimal < 0 ||
        historyPerAnimal > 1000) {
      throw ArgumentError(
        'Fixture dimensions are outside the evaluation limits.',
      );
    }
    if (bind != '127.0.0.1' &&
        (publicOrigin == null || publicOrigin.scheme != 'https')) {
      throw ArgumentError(
        'LAN binding requires an explicit HTTPS public origin.',
      );
    }
    await scratchParent.create(recursive: true);
    final directory = await scratchParent.createTemp('tm186-');
    AccountStore? accounts;
    AppDatabase? database;
    HttpServer? server;
    try {
      if (!Platform.isWindows) {
        final permissions = await Process.run('chmod', ['700', directory.path]);
        if (permissions.exitCode != 0) {
          throw StateError('Cannot protect scratch directory.');
        }
      }
      accounts = await AccountStore.open(
        File('${directory.path}/accounts.sqlite'),
      );
      final random = Random.secure();
      final password = base64UrlEncode(
        List.generate(30, (_) => random.nextInt(256)),
      );
      final administrator = await accounts.createInitialAdministrator(
        'evaluation-admin',
        password,
      );
      final clientAccounts = <Map<String, String>>[];
      if (integrated) {
        for (var i = 1; i <= 3; i++) {
          final username = 'evaluation-client-$i';
          await accounts.createAccount(
            username,
            password,
            CareRole.caregiver,
            actor: administrator,
          );
          clientAccounts.add({'username': username, 'password': password});
        }
      }
      final fixtureId = base64UrlEncode(
        List.generate(24, (_) => random.nextInt(256)),
      );
      database = await openServerDatabase(
        File('${directory.path}/collection.sqlite'),
      );
      await _seed(database, animalCount, historyPerAnimal);
      await CollectionAuditLog(database).initialize();
      server = await HttpServer.bind(InternetAddress(bind), port);
      final origin =
          publicOrigin ?? Uri.parse('http://localhost:${server.port}');
      if (origin.userInfo.isNotEmpty ||
          origin.query.isNotEmpty ||
          origin.fragment.isNotEmpty ||
          (origin.path != '' && origin.path != '/')) {
        throw ArgumentError(
          'Public origin must contain only scheme, host and port.',
        );
      }
      final api = SharedServerApi(
        database: database,
        accounts: accounts,
        publicUrl: origin,
      );
      final lab = UpdateEvaluationLab._(
        server,
        directory,
        database,
        accounts,
        api,
        SessionAuthenticator(accounts, origin),
        assets,
        {
          'animals': animalCount,
          'boxes': 5,
          'feedings': animalCount * historyPerAnimal,
        },
        integrated,
        fixtureId,
      );
      await File('${directory.path}/credentials.json').writeAsString(
        jsonEncode({
          'origin': origin.origin,
          'username': 'evaluation-admin',
          'password': password,
          if (integrated) ...{
            'kind': 'disposable-integrated-shared-care',
            'fixtureId': fixtureId,
            'clients': clientAccounts,
          },
        }),
      );
      server.listen((request) => unawaited(lab._handle(request)));
      return lab;
    } catch (_) {
      await server?.close(force: true);
      await database?.close();
      accounts?.close();
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  static Future<void> _seed(
    AppDatabase database,
    int animals,
    int history,
  ) async {
    await database.transaction(() async {
      await database.batch((batch) {
        batch.insertAll(database.boxes, [
          for (var i = 1; i <= 5; i++)
            BoxesCompanion.insert(
              qrId: 'tm186-box-$i',
              name: Value('Evaluation Box $i'),
            ),
        ]);
        batch.insertAll(database.animals, [
          for (var i = 1; i <= animals; i++)
            AnimalsCompanion.insert(
              boxId: Value((i - 1) % 5 + 1),
              commonName: 'Evaluation Animal $i',
              latinName: 'Example species $i',
              tempMin: 22,
              tempMax: 28,
              humidityMin: 40,
              humidityMax: 60,
              feedingReminderIntervalDays: const Value(7),
              feedingReminderBaseline: Value(DateTime.utc(2025)),
            ),
        ]);
        batch.insertAll(database.feedingEvents, [
          for (var i = 1; i <= animals; i++)
            for (var j = 0; j < history; j++)
              FeedingEventsCompanion.insert(
                animalId: i,
                fedAt: DateTime.utc(2025).add(Duration(days: j)),
                notes: const Value('Synthetic evaluation history'),
              ),
        ]);
      });
    });
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.update(
      '${request.method} ${path.replaceAll(RegExp(r'/\d+(?=/|$)'), '/:id')}',
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    try {
      if (path.startsWith('/api/')) {
        await api.handle(request);
        // This wrapper observes the completed real API request, after commit and
        // response delivery. It is NOT a production transactional change hook.
        if (!integrated &&
            path == '/api/v1/feedings' &&
            request.method == 'POST' &&
            request.response.statusCode >= 200 &&
            request.response.statusCode < 300) {
          feed.publish();
        }
        return;
      }
      final file = switch (path) {
        '/' => 'index.html',
        '/evaluation/client.js' => 'client.js',
        _ => null,
      };
      if (!integrated && file != null && request.method == 'GET') {
        request.response.headers.contentType = ContentType.parse(
          file.endsWith('.js')
              ? 'text/javascript; charset=utf-8'
              : 'text/html; charset=utf-8',
        );
        request.response.headers.set('Cache-Control', 'no-store');
        request.response.add(await File('${assets.path}/$file').readAsBytes());
        await request.response.close();
        return;
      }
      sessions.checkOrigin(request);
      if (sessions.session(request) == null) {
        await sendApiResponse(request.response, 401, {'error': 'unauthorized'});
        return;
      }
      if (request.method != 'GET') {
        await sendApiResponse(request.response, 405, {
          'error': 'read_only_evaluation_endpoint',
        });
        return;
      }
      if (integrated &&
          !{'/evaluation/state', '/evaluation/metrics'}.contains(path)) {
        await sendApiResponse(request.response, 404, {'error': 'not_found'});
        return;
      }
      switch (path) {
        case '/evaluation/state':
          await sendApiResponse(request.response, 200, {
            if (!integrated) 'cursor': feed.cursor,
            if (integrated) 'fixtureId': fixtureId,
            'fixture': fixture,
            'kind': integrated
                ? 'disposable-integrated-shared-care'
                : 'disposable-transport-lab',
            'timeUtc': DateTime.now().toUtc().toIso8601String(),
          });
        case '/evaluation/metrics':
          await sendApiResponse(request.response, 200, {
            'requests': requests,
            'streams': integrated
                ? api.changeStreams.activeConnections
                : _streams,
            if (integrated)
              'maximumConnections': api.changeStreams.maximumConnections,
            if (integrated)
              'maximumPerAccount': api.changeStreams.maximumPerAccount,
          });
        case '/evaluation/changes':
          await _changes(request);
        case '/evaluation/events':
          await _sse(request);
        case '/evaluation/socket':
          await _websocket(request);
        default:
          await sendApiResponse(request.response, 404, {'error': 'not_found'});
      }
    } on ApiProblem catch (error) {
      await sendApiResponse(request.response, error.status, {
        'error': error.code,
      });
    } catch (_) {
      try {
        await sendApiResponse(request.response, 500, {
          'error': 'evaluation_request_failed',
        });
      } catch (_) {
        // A disconnected probe must not crash the server.
      }
    }
  }

  bool _authenticated(HttpRequest request) => sessions.session(request) != null;

  Future<void> _changes(HttpRequest request) async {
    final previous = request.uri.queryParameters['after'];
    if (request.uri.queryParameters['wait'] == '1' && previous == feed.cursor) {
      if (_streams >= 32) {
        await sendApiResponse(request.response, 429, {
          'error': 'evaluation_connection_limit',
        });
        return;
      }
      _streams++;
      try {
        await feed.changes.first.timeout(
          const Duration(seconds: 25),
          onTimeout: () {},
        );
      } finally {
        _streams--;
      }
    }
    if (!_authenticated(request)) {
      await sendApiResponse(request.response, 401, {'error': 'unauthorized'});
      return;
    }
    request.response.headers.set('ETag', feed.etag);
    request.response.headers.set('Cache-Control', 'no-store');
    if (previous == feed.cursor &&
        request.headers.value(HttpHeaders.ifNoneMatchHeader) == feed.etag) {
      request.response.statusCode = 304;
      await request.response.close();
    } else {
      await sendApiResponse(request.response, 200, feed.since(previous));
    }
  }

  Future<void> _sse(HttpRequest request) async {
    if (_streams >= 32) {
      await sendApiResponse(request.response, 429, {
        'error': 'evaluation_connection_limit',
      });
      return;
    }
    _streams++;
    final response = request.response;
    response.bufferOutput = false;
    response.headers.contentType = ContentType(
      'text',
      'event-stream',
      charset: 'utf-8',
    );
    response.headers.set('Cache-Control', 'no-store');
    // A dedicated close-delimited connection lets us observe a peer FIN even
    // while no event is being written. HttpResponse.done alone does not do so.
    response.persistentConnection = false;
    response.headers.chunkedTransferEncoding = false;
    late final Socket socket;
    try {
      socket = await response.detachSocket();
    } catch (_) {
      _streams--;
      rethrow;
    }
    var previous =
        request.headers.value('Last-Event-ID') ??
        request.uri.queryParameters['after'];
    var sending = false;
    var dirty = false;
    var closed = false;
    final done = Completer<void>();
    Future<void> disconnect() async {
      if (closed) return;
      closed = true;
      if (!done.isCompleted) done.complete();
      socket.destroy();
    }

    final incoming = socket.listen(
      (_) {},
      onDone: () => unawaited(disconnect()),
      onError: (Object error, StackTrace stack) => unawaited(disconnect()),
      cancelOnError: true,
    );
    socket.done
        .then<void>(
          (_) => disconnect(),
          onError: (Object error, StackTrace stack) => disconnect(),
        )
        .ignore();

    Future<void> send() async {
      if (closed) return;
      if (sending) {
        dirty = true;
        return;
      }
      sending = true;
      try {
        do {
          dirty = false;
          if (!_authenticated(request)) {
            socket.add(utf8.encode('event: session-expired\ndata: {}\n\n'));
            await socket.flush().timeout(const Duration(seconds: 2));
            await disconnect();
            break;
          }
          final update = feed.since(previous);
          final next = update['cursor'] as String;
          if (next != previous || update['reset'] == true) {
            socket.add(
              utf8.encode(
                'id: $next\nevent: changes\ndata: ${jsonEncode(update)}\n\n',
              ),
            );
            previous = next;
          } else {
            socket.add(utf8.encode(': heartbeat\n\n'));
          }
          await socket.flush().timeout(const Duration(seconds: 2));
        } while (dirty && !closed);
      } catch (_) {
        await disconnect();
      } finally {
        sending = false;
      }
    }

    _disconnect.add(disconnect);
    final subscription = feed.changes.listen((_) => unawaited(send()));
    final timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(send()),
    );
    try {
      await send();
      await done.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
      await incoming.cancel();
      socket.destroy();
      _disconnect.remove(disconnect);
      _streams--;
    }
  }

  Future<void> _websocket(HttpRequest request) async {
    if (_streams >= 32 || !WebSocketTransformer.isUpgradeRequest(request)) {
      await sendApiResponse(request.response, 400, {
        'error': 'invalid_evaluation_socket',
      });
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    _streams++;
    var previous = request.uri.queryParameters['after'];
    Future<void> disconnect() async {
      await socket.close(WebSocketStatus.goingAway);
    }

    void send() {
      if (socket.readyState != WebSocket.open) return;
      if (!_authenticated(request)) {
        unawaited(disconnect());
        return;
      }
      final update = feed.since(previous);
      previous = update['cursor'] as String;
      socket.add(jsonEncode(update));
    }

    _disconnect.add(disconnect);
    final subscription = feed.changes.listen((_) => send());
    final heartbeat = Timer.periodic(
      const Duration(seconds: 15),
      (_) => send(),
    );
    try {
      send();
      await socket.drain<void>();
    } finally {
      heartbeat.cancel();
      await subscription.cancel();
      _disconnect.remove(disconnect);
      _streams--;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final disconnect in _disconnect.toList()) {
      await disconnect();
    }
    api.changeStreams.close();
    await server.close(force: true);
    while (api.changeStreams.activeConnections != 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await feed.close();
    await database.close();
    accounts.close();
    // Delete only the unique scratch directory created by this instance.
    final resolved = await directory.resolveSymbolicLinks();
    final parent = await directory.parent.resolveSymbolicLinks();
    if (!resolved.startsWith(parent + Platform.pathSeparator) ||
        !directory.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last
            .startsWith('tm186-')) {
      throw StateError('Unexpected evaluation scratch path.');
    }
    await directory.delete(recursive: true);
  }
}

Future<void> main(List<String> args) async {
  if (args.contains('--help') || !args.contains('--serve')) {
    stdout.writeln(
      'Disposable Shared Care evaluation server. --serve [--bind ADDRESS] '
      '[--port PORT] [--public-origin HTTPS_ORIGIN] [--animals N] [--history N] '
      '[--scratch-parent PATH] [--assets PATH] [--integrated]',
    );
    return;
  }
  String option(String name, String fallback) {
    final index = args.indexOf(name);
    if (index == -1) return fallback;
    if (index + 1 >= args.length) {
      throw ArgumentError('Missing value for $name');
    }
    return args[index + 1];
  }

  final publicText = option('--public-origin', '');
  final lab = await UpdateEvaluationLab.start(
    scratchParent: Directory(
      option('--scratch-parent', Directory.systemTemp.path),
    ),
    assets: Directory(option('--assets', 'tool/evaluation/shared_updates/web')),
    bind: option('--bind', '127.0.0.1'),
    port: int.parse(option('--port', '0')),
    animalCount: int.parse(option('--animals', '100')),
    historyPerAnimal: int.parse(option('--history', '20')),
    publicOrigin: publicText.isEmpty ? null : Uri.parse(publicText),
    integrated: args.contains('--integrated'),
  );
  stdout.writeln(
    jsonEncode({
      'listenerPort': lab.server.port,
      'credentialsFile': '${lab.directory.path}/credentials.json',
      'fixture': lab.fixture,
      'warning': lab.integrated
          ? 'DISPOSABLE DATA; PRODUCTION API/SSE; FLUTTER SERVED BY GATEWAY'
          : 'DISPOSABLE LAB; NO PRODUCTION DATABASE; NOT THE FLUTTER UI',
    }),
  );
  var shuttingDown = false;
  Future<void> shutdown() async {
    if (shuttingDown) return;
    shuttingDown = true;
    await lab.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => unawaited(shutdown()));
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => unawaited(shutdown()));
  }
}
