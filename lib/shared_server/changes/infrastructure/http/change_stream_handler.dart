import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/http/session_authenticator.dart';
import 'package:terramanager/shared_server/changes/application/committed_changes.dart';
import 'package:terramanager/shared_server/changes/application/coalescing_stream_writer.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

/// Close-delimited HTTP/1.1 upstream, also usable through Caddy HTTP/2 or HTTP/3.
/// Socket ownership is necessary to observe an idle peer disconnect on Dart IO.
/// No collection transaction or backup gate is held during the subscription.
class ChangeStreamHandler {
  ChangeStreamHandler(
    this.changes,
    this.accounts,
    this.sessions, {
    this.maximumConnections = 32,
    this.maximumPerAccount = 8,
    this.heartbeat = const Duration(seconds: 15),
    this.writeTimeout = const Duration(seconds: 2),
  }) {
    if (maximumConnections < 1 ||
        maximumPerAccount < 1 ||
        heartbeat <= Duration.zero ||
        writeTimeout <= Duration.zero) {
      throw ArgumentError('Stream limits and durations must be positive.');
    }
  }

  final CommittedChanges changes;
  final AccountStore accounts;
  final SessionAuthenticator sessions;
  final int maximumConnections;
  final int maximumPerAccount;
  final Duration heartbeat;
  final Duration writeTimeout;
  static const maximumFrameBytes = 64 * 1024;
  final _connections = <void Function()>{};
  final _perAccount = <String, int>{};
  int _reserved = 0;
  bool _closed = false;
  int get activeConnections => _reserved;

  void close() {
    _closed = true;
    for (final disconnect in _connections.toList()) {
      disconnect();
    }
  }

  Future<void> handle(HttpRequest request, CareSession initial) async {
    if (request.uri.hasQuery) {
      throw const ApiProblem(
        400,
        'invalid_data',
        'Stream URLs accept no query.',
      );
    }
    final after = request.headers.value('Last-Event-ID');
    if (after != null && after.length > 200) {
      throw const ApiProblem(400, 'invalid_data', 'Invalid event cursor.');
    }
    final owner = '${initial.account.id}.${initial.account.auditId}';
    if (_closed) {
      throw const ApiProblem(503, 'unavailable', 'Server is stopping.');
    }
    if (_reserved >= maximumConnections ||
        (_perAccount[owner] ?? 0) >= maximumPerAccount) {
      request.response.headers.set('Retry-After', '15');
      throw const ApiProblem(
        429,
        'stream_limit',
        'Too many open change streams.',
      );
    }
    _reserved++;
    _perAccount.update(owner, (n) => n + 1, ifAbsent: () => 1);
    Socket? socket;
    StreamSubscription<List<int>>? incoming;
    StreamSubscription<void>? collection;
    StreamSubscription<int?>? account;
    Timer? beat;
    Timer? expiry;
    final done = Completer<void>();
    var closed = false;
    CoalescingStreamWriter? writer;
    var previous = after;
    var keepaliveDue = false;
    void disconnect() {
      if (closed) return;
      closed = true;
      writer?.close();
      socket?.destroy();
      if (!done.isCompleted) done.complete();
    }

    _connections.add(disconnect);
    try {
      final response = request.response;
      response.bufferOutput = false;
      response.persistentConnection = false;
      response.headers.chunkedTransferEncoding = false;
      response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      response.headers.set('Cache-Control', 'private, no-store');
      response.headers.set('Vary', 'Cookie');
      response.headers.set('X-Content-Type-Options', 'nosniff');
      socket = await response.detachSocket();
      if (closed) {
        socket.destroy();
        return;
      }
      incoming = socket.listen(
        (_) =>
            disconnect(), // This dedicated response accepts no pipelined data.
        onDone: disconnect,
        onError: (Object error, StackTrace stack) => disconnect(),
        cancelOnError: true,
      );
      socket.done
          .then<void>(
            (_) => disconnect(),
            onError: (Object error, StackTrace stack) => disconnect(),
          )
          .ignore();

      Future<void> send() async {
        final emitKeepalive = keepaliveDue;
        keepaliveDue = false;
        // Re-read before every frame: revocation never sends another hint.
        final current = sessions.session(request);
        if (current == null ||
            current.account.auditId != initial.account.auditId ||
            current.account.role != initial.account.role) {
          socket!.add(utf8.encode('event: auth-required\ndata: {}\n\n'));
          await socket.flush();
          disconnect();
          return;
        }
        var body = changes.query(
          accountKey: owner,
          role: current.account.role.name,
          preferencesRevision: accounts.preferencesRevision(current.account.id),
          since: previous,
        );
        final next = body['cursor'] as String;
        if (next != previous || body['reset'] == true) {
          List<int> frame() => utf8.encode(
            'id: $next\nevent: changes\ndata: ${jsonEncode(body)}\n\n',
          );
          var bytes = frame();
          if (bytes.length > maximumFrameBytes) {
            body = changes.query(
              accountKey: owner,
              role: current.account.role.name,
              preferencesRevision: accounts.preferencesRevision(
                current.account.id,
              ),
            );
            body['reason'] = 'replay_too_large';
            bytes = frame();
          }
          socket!.add(bytes);
          await socket.flush();
          previous = next; // Transport delivery only, never a data-read acknowledgment.
        } else {
          socket!.add(
            utf8.encode(
              emitKeepalive
                  ? 'event: keepalive\ndata: {}\n\n'
                  : ': keepalive\n\n',
            ),
          );
          await socket.flush();
        }
      }

      writer = CoalescingStreamWriter(
        write: send,
        onFailure: disconnect,
        timeout: writeTimeout,
      );
      collection = changes.notifications.listen((_) => writer!.request());
      account = accounts.notifications.listen((id) {
        if (id == null || id == initial.account.id) writer!.request();
      }, onDone: disconnect);
      beat = Timer.periodic(heartbeat, (_) {
        keepaliveDue = true;
        writer!.request();
      });
      final remaining = initial.expiresAt.difference(DateTime.now().toUtc());
      expiry = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        () => writer!.request(),
      );
      writer.request();
      await done.future;
    } catch (_) {
      // After detachment an HTTP JSON error cannot be sent on this connection.
      disconnect();
    } finally {
      disconnect();
      beat?.cancel();
      expiry?.cancel();
      await collection?.cancel();
      await account?.cancel();
      await incoming?.cancel();
      socket?.destroy();
      _connections.remove(disconnect);
      _reserved--;
      final remaining = (_perAccount[owner] ?? 1) - 1;
      if (remaining == 0) {
        _perAccount.remove(owner);
      } else {
        _perAccount[owner] = remaining;
      }
    }
  }
}
