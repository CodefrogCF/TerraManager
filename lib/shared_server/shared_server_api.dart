import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../core/database/app_database.dart';
import '../features/backup/application/backup_validation_exception.dart';
import 'account_store.dart';
import 'api_input.dart';
import 'care_api.dart';
import 'collection_operation_gate.dart';
import 'session_authenticator.dart';
import 'shared_portable_backups.dart';

/// Authenticated entry point for both account management and the care API.
class SharedServerApi {
  final AppDatabase _database;
  final AccountStore accounts;
  final SessionAuthenticator sessions;
  final CareApi _care;
  final SharedPortableBackups _backups;
  final CollectionOperationGate _gate = CollectionOperationGate();
  final Map<String, _SafetyGrant> _safetyGrants = {};
  final Map<String, List<DateTime>> _failedLogins = {};

  SharedServerApi({
    required AppDatabase database,
    required this.accounts,
    required Uri publicUrl,
  }) : _database = database,
       sessions = SessionAuthenticator(accounts, publicUrl),
       _care = CareApi(
         database: database,
         authenticator: SessionAuthenticator(accounts, publicUrl),
       ),
       _backups = SharedPortableBackups(database);

  Future<HttpServer> serve({InternetAddress? address, int port = 0}) async {
    if (!accounts.hasAccounts) {
      throw StateError(
        'Create the initial administrator before starting the server.',
      );
    }
    final server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    server.listen((request) => unawaited(handle(request)));
    return server;
  }

  Future<void> handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/api/v1/health' && request.method == 'GET') {
      try {
        await _database.customSelect('SELECT 1').get();
        await _send(request.response, 200, {'status': 'ok'});
      } catch (_) {
        await _send(request.response, 503, {'status': 'unavailable'});
      }
      return;
    }
    if (!path.startsWith('/api/v1/auth/') &&
        !path.startsWith('/api/v1/admin/')) {
      await _collection(request);
      return;
    }
    try {
      sessions.checkOrigin(request);
      if (path == '/api/v1/auth/login' && request.method == 'POST') {
        await _login(request);
        return;
      }
      final current = sessions.session(request);
      if (current == null) {
        throw const ApiProblem(401, 'unauthorized', 'Authentication required.');
      }
      if (!{'GET', 'HEAD', 'OPTIONS'}.contains(request.method)) {
        sessions.checkMutation(request, current);
      }
      if (path == '/api/v1/auth/session' && request.method == 'GET') {
        await _send(request.response, 200, {
          'user': current.account.toJson(),
          'csrfToken': current.csrfToken,
          'expiresAt': current.expiresAt.toIso8601String(),
        });
        return;
      }
      if (path == '/api/v1/auth/logout' && request.method == 'POST') {
        accounts.revokeSession(current.token);
        request.response.headers.add(
          HttpHeaders.setCookieHeader,
          SessionAuthenticator.clearCookieHeader(),
        );
        await _send(request.response, 200, {'loggedOut': true});
        return;
      }
      if (path.startsWith('/api/v1/admin/')) {
        if (current.account.role != CareRole.administrator) {
          throw const ApiProblem(
            403,
            'forbidden',
            'Administrator access required.',
          );
        }
        await _admin(request, current);
        return;
      }
      throw const ApiProblem(404, 'not_found', 'Unknown API path.');
    } on ApiProblem catch (error) {
      await _send(request.response, error.status, {
        'error': {'code': error.code, 'message': error.message},
      });
    } on BackupValidationException catch (error) {
      await _send(request.response, 400, {
        'error': {'code': 'invalid_backup', 'message': error.message},
      });
    } on FormatException catch (error) {
      await _send(request.response, 400, {
        'error': {'code': 'invalid_data', 'message': error.message},
      });
    } on SqliteException catch (error) {
      await _send(
        request.response,
        error.extendedResultCode == 2067 ? 409 : 500,
        {
          'error': {
            'code': error.extendedResultCode == 2067
                ? 'conflict'
                : 'internal_error',
            'message': error.extendedResultCode == 2067
                ? 'Username already exists.'
                : 'Request could not be completed.',
          },
        },
      );
    } on StateError catch (error) {
      await _send(request.response, 409, {
        'error': {'code': 'conflict', 'message': error.message},
      });
    } catch (_) {
      await _send(request.response, 500, {
        'error': {
          'code': 'internal_error',
          'message': 'Request could not be completed.',
        },
      });
    }
  }

  Future<void> _collection(HttpRequest request) async {
    final mutation = !{'GET', 'HEAD', 'OPTIONS'}.contains(request.method);
    if (mutation) {
      final current = sessions.session(request);
      if (current == null) {
        await _care.handle(request);
        return;
      }
      try {
        sessions.checkMutation(request, current);
      } on ApiProblem {
        await _care.handle(request);
        return;
      }
      if (!_gate.enterMutation()) {
        await _send(request.response, 503, {
          'error': {
            'code': 'restore_in_progress',
            'message': 'The shared collection is temporarily unavailable.',
          },
        });
        return;
      }
      try {
        await _care.handle(request);
      } finally {
        _gate.leaveMutation();
      }
      return;
    }
    if (_gate.exclusive) {
      if (sessions.session(request) == null) {
        await _care.handle(request);
        return;
      }
      await _send(request.response, 503, {
        'error': {
          'code': 'restore_in_progress',
          'message': 'The shared collection is temporarily unavailable.',
        },
      });
      return;
    }
    await _care.handle(request);
  }

  Future<void> _login(HttpRequest request) async {
    final input = await _body(request);
    input.allow(const {'username', 'password'});
    final username = input.string('username', maxLength: 64).toLowerCase();
    final password = _password(input);
    final key = '${request.connectionInfo?.remoteAddress.address}:$username';
    final now = DateTime.now().toUtc();
    _failedLogins.removeWhere((_, attempts) {
      attempts.removeWhere(
        (time) => now.difference(time) > const Duration(minutes: 5),
      );
      return attempts.isEmpty;
    });
    if ((_failedLogins[key]?.length ?? 0) >= 5) {
      throw const ApiProblem(429, 'rate_limited', 'Try again later.');
    }
    final account = await accounts.authenticate(username, password);
    if (account == null) {
      if (_failedLogins.length > 1000) _failedLogins.clear();
      _failedLogins.putIfAbsent(key, () => []).add(now);
      throw const ApiProblem(
        401,
        'invalid_credentials',
        'Invalid credentials.',
      );
    }
    _failedLogins.remove(key);
    final session = accounts.createSession(account);
    request.response.headers.add(
      HttpHeaders.setCookieHeader,
      SessionAuthenticator.cookieHeader(session.token),
    );
    await _send(request.response, 200, {
      'user': account.toJson(),
      'csrfToken': session.csrfToken,
      'expiresAt': session.expiresAt.toIso8601String(),
    });
  }

  Future<void> _admin(HttpRequest request, CareSession current) async {
    final parts = request.uri.pathSegments;
    if (parts.length == 4 && parts[3] == 'backups' && request.method == 'GET') {
      await _exportBackup(request, current);
      return;
    }
    if (parts.length == 5 &&
        parts[3] == 'backups' &&
        parts[4] == 'restore' &&
        request.method == 'POST') {
      await _restoreBackup(request, current);
      return;
    }
    if (parts.length == 4 && parts[3] == 'accounts') {
      if (request.method == 'GET') {
        await _send(request.response, 200, {
          'accounts': accounts
              .listAccounts()
              .map((account) => account.toJson())
              .toList(),
        });
        return;
      }
      if (request.method == 'POST') {
        final input = await _body(request);
        input.allow(const {'username', 'password', 'role'});
        final account = await accounts.createAccount(
          input.string('username', maxLength: 64),
          _password(input),
          _role(input.string('role', maxLength: 32)),
        );
        await _send(request.response, 201, {'account': account.toJson()});
        return;
      }
    }
    if (parts.length == 5 &&
        parts[3] == 'accounts' &&
        request.method == 'PATCH') {
      final id = int.tryParse(parts[4]);
      if (id == null || id < 1) {
        throw const ApiProblem(400, 'invalid_data', 'Invalid account ID.');
      }
      if (accounts.accountById(id) == null) {
        throw const ApiProblem(404, 'not_found', 'Account not found.');
      }
      final input = await _body(request);
      input.allow(const {'password', 'role', 'active'});
      if (input.values.isEmpty) {
        throw const ApiProblem(400, 'invalid_data', 'No fields to update.');
      }
      final active = input.values['active'];
      if (active != null && active is! bool) {
        throw const ApiProblem(400, 'invalid_data', 'active must be Boolean.');
      }
      final account = await accounts.updateAccount(
        id,
        password: input.values.containsKey('password')
            ? _password(input)
            : null,
        role: input.values.containsKey('role')
            ? _role(input.string('role', maxLength: 32))
            : null,
        active: active as bool?,
      );
      await _send(request.response, 200, {'account': account.toJson()});
      return;
    }
    throw const ApiProblem(
      404,
      'not_found',
      'Unknown administrator operation.',
    );
  }

  Future<void> _exportBackup(HttpRequest request, CareSession current) async {
    if (!await _gate.enterExclusive()) {
      throw const ApiProblem(
        503,
        'restore_in_progress',
        'The shared collection is temporarily unavailable.',
      );
    }
    try {
      final exported = await _backups.export();
      final random = Random.secure();
      final token = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      final now = DateTime.now().toUtc();
      _safetyGrants.removeWhere((_, grant) => now.isAfter(grant.expiresAt));
      _safetyGrants[current.token] = _SafetyGrant(
        token,
        _gate.generation,
        now.add(const Duration(minutes: 30)),
      );
      final response = request.response;
      response.statusCode = 200;
      response.headers.contentType = ContentType.parse(
        'application/vnd.terramanager.backup+zip',
      );
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.headers.set('X-Safety-Token', token);
      response.headers.set(
        'Content-Disposition',
        'attachment; filename="${exported.fileName}"',
      );
      response.add(exported.bytes);
      await response.close();
    } finally {
      _gate.leaveExclusive();
    }
  }

  Future<void> _restoreBackup(HttpRequest request, CareSession current) async {
    if (request.headers.value('X-Restore-Confirmation') !=
        'replace-shared-collection') {
      throw const ApiProblem(
        400,
        'confirmation_required',
        'Explicit restore confirmation is required.',
      );
    }
    final grant = _safetyGrants[current.token];
    if (grant == null ||
        grant.token != request.headers.value('X-Safety-Token') ||
        DateTime.now().toUtc().isAfter(grant.expiresAt)) {
      throw const ApiProblem(
        409,
        'safety_backup_required',
        'Download a current safety backup before restoring.',
      );
    }
    final bytes = await _backupBody(request);
    final validated = _backups.validate(bytes);
    if (!await _gate.enterExclusive()) {
      throw const ApiProblem(
        503,
        'restore_in_progress',
        'The shared collection is temporarily unavailable.',
      );
    }
    try {
      if (grant.generation != _gate.generation) {
        throw const ApiProblem(
          409,
          'safety_backup_stale',
          'The collection changed. Download a new safety backup.',
        );
      }
      final mediaCount = await _backups.restore(validated);
      _care.clearRequestCache();
      _safetyGrants.clear();
      await _send(request.response, 200, {
        'restored': true,
        'boxes': validated.boxCount,
        'animals': validated.animalCount,
        'feedings': validated.feedingEventCount,
        'media': mediaCount,
      });
    } finally {
      _gate.leaveExclusive();
    }
  }

  static Future<Uint8List> _backupBody(HttpRequest request) async {
    if (request.headers.contentType?.mimeType !=
        'application/vnd.terramanager.backup+zip') {
      throw const ApiProblem(
        415,
        'unsupported_media_type',
        'Expected a TerraManager backup archive.',
      );
    }
    const maxBytes = 256 * 1024 * 1024;
    if (request.contentLength > maxBytes) {
      throw const ApiProblem(413, 'too_large', 'Backup exceeds 256 MiB.');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw const ApiProblem(413, 'too_large', 'Backup exceeds 256 MiB.');
      }
    }
    return builder.takeBytes();
  }

  static CareRole _role(String value) {
    if (value == CareRole.administrator.name) return CareRole.administrator;
    if (value == CareRole.caregiver.name) return CareRole.caregiver;
    throw const ApiProblem(400, 'invalid_data', 'Unknown account role.');
  }

  static String _password(ApiInput input) {
    final value = input.values['password'];
    if (value is! String || utf8.encode(value).length > 1024) {
      throw const ApiProblem(400, 'invalid_data', 'Invalid password.');
    }
    return value;
  }

  static Future<ApiInput> _body(HttpRequest request) async {
    if (request.headers.contentType?.mimeType != 'application/json') {
      throw const ApiProblem(
        415,
        'unsupported_media_type',
        'Content-Type must be application/json.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > 16384) {
        throw const ApiProblem(413, 'too_large', 'Request body is too large.');
      }
    }
    try {
      return ApiInput.decode(utf8.decode(builder.takeBytes()));
    } on FormatException {
      throw const ApiProblem(400, 'invalid_json', 'Expected UTF-8 JSON.');
    }
  }

  static Future<void> _send(
    HttpResponse response,
    int status,
    Object body,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.write(jsonEncode(body));
    await response.close();
  }
}

class _SafetyGrant {
  const _SafetyGrant(this.token, this.generation, this.expiresAt);

  final String token;
  final int generation;
  final DateTime expiresAt;
}
