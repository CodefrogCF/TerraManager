import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart' show SqlError, SqliteException;
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_lifecycle_exception.dart';
import 'package:terramanager/shared_server/animals/application/animal_history_operations.dart';
import 'package:terramanager/shared_server/animals/application/animal_operations.dart';
import 'package:terramanager/shared_server/animals/infrastructure/http/animal_handler.dart';
import 'package:terramanager/shared_server/animals/infrastructure/http/animal_history_handler.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/http/care_authenticator.dart';
import 'package:terramanager/shared_server/boxes/application/box_operations.dart';
import 'package:terramanager/shared_server/boxes/infrastructure/http/box_handler.dart';
import 'package:terramanager/shared_server/feedings/application/feeding_operations.dart';
import 'package:terramanager/shared_server/feedings/application/feeding_reminder_operations.dart';
import 'package:terramanager/shared_server/feedings/infrastructure/http/feeding_handler.dart';
import 'package:terramanager/shared_server/media/application/media_operations.dart';
import 'package:terramanager/shared_server/media/infrastructure/http/media_handler.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/domain/api_reply.dart';

typedef CareAuditWriter = Future<void> Function(
  HttpRequest request,
  int status,
  Map<String, dynamic>? reply,
  bool replayed,
);

class CareApi {
  final AppDatabase database;
  final CareAuthenticator authenticator;
  final CareAuditWriter? audit;

  late final _feedingOperations = FeedingOperations(database);
  late final _mediaHandler = MediaHandler(MediaOperations(database));
  late final _historyHandler = AnimalHistoryHandler(
    AnimalHistoryOperations(database),
  );
  late final _boxHandler = BoxHandler(
    operations: BoxOperations(database),
    pictures: _mediaHandler,
  );
  late final _animalHandler = AnimalHandler(
    operations: AnimalOperations(database),
    pictures: _mediaHandler,
    history: _historyHandler,
    feedings: _feedingOperations,
  );
  late final _feedingHandler = FeedingHandler(operations: _feedingOperations);
  late final _reminderOperations = FeedingReminderOperations(database);

  CareApi({required this.database, required this.authenticator, this.audit});

  void clearRequestCache() => _feedingOperations.clearRequestCache();

  Future<HttpServer> serve({InternetAddress? address, int port = 0}) async {
    final server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    server.listen((request) {
      unawaited(handle(request));
    });
    return server;
  }

  Future<void> handle(HttpRequest request) async {
    try {
      if (!await authenticator.isAuthenticated(request)) {
        throw const ApiProblem(401, 'unauthorized', 'Authentication required.');
      }
      final reply = await _auditedDispatch(request);
      await _send(request.response, reply);
    } on ApiProblem catch (problem) {
      await _send(
        request.response,
        ApiReply(problem.status, {
          'error': {'code': problem.code, 'message': problem.message},
        }),
      );
    } on BoxArchiveBlockedException {
      await _send(
        request.response,
        apiError(409, 'conflict', 'Box contains active Animals.'),
      );
    } on BoxAssignmentException {
      await _send(
        request.response,
        apiError(409, 'conflict', 'Destination Box is not active.'),
      );
    } on ArgumentError catch (error) {
      await _send(
        request.response,
        apiError(
          400,
          'invalid_data',
          error.message?.toString() ?? 'Invalid data.',
        ),
      );
    } on StateError {
      await _send(
        request.response,
        apiError(409, 'conflict', 'Operation conflicts with current data.'),
      );
    } on SqliteException catch (error) {
      await _send(
        request.response,
        error.resultCode == SqlError.SQLITE_CONSTRAINT ||
                error.resultCode == SqlError.SQLITE_BUSY ||
                error.resultCode == SqlError.SQLITE_LOCKED
            ? apiError(409, 'conflict', 'Database state prevents this change.')
            : apiError(
                500,
                'internal_error',
                'The request could not be completed.',
              ),
      );
    } catch (_) {
      await _send(
        request.response,
        apiError(500, 'internal_error', 'The request could not be completed.'),
      );
    }
  }

  Future<ApiReply> _auditedDispatch(HttpRequest request) async {
    if (audit == null ||
        const {'GET', 'HEAD', 'OPTIONS'}.contains(request.method)) {
      return _dispatch(request);
    }
    try {
      return await database.transaction(() async {
        final reply = await _dispatch(request);
        if (reply.status >= 400) throw _RejectedReply(reply);
        await audit!(request, reply.status, reply.body, reply.replayed);
        return reply;
      });
    } on _RejectedReply catch (rejected) {
      await audit!(request, rejected.reply.status, null, false);
      return rejected.reply;
    } catch (error) {
      // Cached Feeding replies must never outlive a rolled-back transaction.
      clearRequestCache();
      final status = error is ApiProblem
          ? error.status
          : error is BoxArchiveBlockedException ||
                error is BoxAssignmentException ||
                error is StateError
          ? 409
          : error is ArgumentError
          ? 400
          : error is SqliteException &&
                (error.resultCode == SqlError.SQLITE_CONSTRAINT ||
                    error.resultCode == SqlError.SQLITE_BUSY ||
                    error.resultCode == SqlError.SQLITE_LOCKED)
          ? 409
          : 500;
      await audit!(request, status, null, false);
      rethrow;
    }
  }

  Future<ApiReply> _dispatch(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (segments.length < 3 || segments[0] != 'api' || segments[1] != 'v1') {
      return apiError(404, 'not_found', 'Unknown API path.');
    }
    final path = segments.skip(2).toList(growable: false);
    final method = request.method;
    if (path[0] == 'boxes') return _boxHandler.handle(path, method, request);
    if (path[0] == 'animals') {
      return _animalHandler.handle(path, method, request);
    }
    if (path[0] == 'feedings') {
      return _feedingHandler.handle(path, method, request);
    }
    if (path[0] == 'reminders' && path.length == 1 && method == 'GET') {
      return _reminderOperations.list();
    }
    if (path[0] == 'media') return _mediaHandler.handle(path, method, request);
    return apiError(404, 'not_found', 'Unknown API path.');
  }

  static Future<void> _send(HttpResponse response, ApiReply reply) async {
    response.statusCode = reply.status;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    if (reply.bytes != null) {
      response.headers.contentType = ContentType.parse(reply.mimeType!);
      response.add(reply.bytes!);
    } else {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(reply.body));
    }
    await response.close();
  }
}

class _RejectedReply implements Exception {
  const _RejectedReply(this.reply);
  final ApiReply reply;
}
