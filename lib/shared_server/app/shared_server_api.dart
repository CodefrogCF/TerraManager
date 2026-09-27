import 'dart:async';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/features/backup/application/backup_validation_exception.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/http/account_administration_handler.dart';
import 'package:terramanager/shared_server/audit/application/rejected_administration_audit.dart';
import 'package:terramanager/shared_server/audit/domain/audit_event.dart';
import 'package:terramanager/shared_server/audit/infrastructure/collection_audit_log.dart';
import 'package:terramanager/shared_server/audit/infrastructure/http/audit_handler.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/http/authentication_handler.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/http/session_authenticator.dart';
import 'package:terramanager/shared_server/backups/infrastructure/http/backup_handler.dart';
import 'package:terramanager/shared_server/collection/application/collection_operation_gate.dart';
import 'package:terramanager/shared_server/collection/infrastructure/http/care_api.dart';
import 'package:terramanager/shared_server/collection/infrastructure/http/collection_handler.dart';
import 'package:terramanager/shared_server/settings/infrastructure/http/preferences_handler.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_response.dart';

/// Authenticated entry point for both account management and the care API.
class SharedServerApi {
  final AppDatabase _database;
  final AccountStore accounts;
  final SessionAuthenticator sessions;
  final CareApi _care;
  final CollectionOperationGate _gate = CollectionOperationGate();
  late final _authentication = AuthenticationHandler(accounts);
  late final _preferences = PreferencesHandler(accounts);
  late final _collectionHandler = CollectionHandler(_care, sessions, _gate);
  late final _accountAdministration = AccountAdministrationHandler(accounts);
  late final _audit = AuditHandler(_database, accounts, _gate);
  late final _backupHandler = BackupHandler(_database, _care, _gate);
  late final _rejectedAudit = RejectedAdministrationAudit(_database, accounts);

  SharedServerApi({
    required AppDatabase database,
    required this.accounts,
    required Uri publicUrl,
  }) : _database = database,
       sessions = SessionAuthenticator(accounts, publicUrl),
       _care = CareApi(
         database: database,
         authenticator: SessionAuthenticator(accounts, publicUrl),
         audit: (request, status, reply, replayed) async {
           final actor = SessionAuthenticator(
             accounts,
             publicUrl,
           ).session(request)?.account;
           if (actor == null) throw StateError('Audit actor is unavailable.');
           for (final event in collectionAuditEvents(
             actor.auditActor,
             request.method,
             request.uri.pathSegments.skip(2).toList(),
             status,
             reply,
             replayed: replayed,
           )) {
             await CollectionAuditLog(database).record(event);
           }
         },
       );

  Future<HttpServer> serve({InternetAddress? address, int port = 0}) async {
    if (!accounts.hasAccounts) {
      throw StateError(
        'Create the initial administrator before starting the server.',
      );
    }
    await CollectionAuditLog(_database).initialize();
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
        await sendApiResponse(request.response, 200, {'status': 'ok'});
      } catch (_) {
        await sendApiResponse(request.response, 503, {'status': 'unavailable'});
      }
      return;
    }
    if (!path.startsWith('/api/v1/auth/') &&
        !path.startsWith('/api/v1/admin/')) {
      await _collectionHandler.handle(request);
      return;
    }
    try {
      sessions.checkOrigin(request);
      if (path == '/api/v1/auth/login' && request.method == 'POST') {
        await _authentication.login(request);
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
        await _authentication.session(request, current);
        return;
      }
      if (path == '/api/v1/auth/preferences') {
        if (await _preferences.handle(request, current)) return;
      }
      if (path == '/api/v1/auth/logout' && request.method == 'POST') {
        await _authentication.logout(request, current);
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
        try {
          await _admin(request, current);
        } catch (error) {
          await _rejectedAudit.record(
            request.method,
            request.uri.pathSegments,
            current.account,
            error,
          );
          rethrow;
        }
        return;
      }
      throw const ApiProblem(404, 'not_found', 'Unknown API path.');
    } on ApiProblem catch (error) {
      await sendApiResponse(request.response, error.status, {
        'error': {'code': error.code, 'message': error.message},
      });
    } on BackupValidationException catch (error) {
      await sendApiResponse(request.response, 400, {
        'error': {'code': 'invalid_backup', 'message': error.message},
      });
    } on FormatException catch (error) {
      await sendApiResponse(request.response, 400, {
        'error': {'code': 'invalid_data', 'message': error.message},
      });
    } on SqliteException catch (error) {
      await sendApiResponse(
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
      await sendApiResponse(request.response, 409, {
        'error': {'code': 'conflict', 'message': error.message},
      });
    } catch (_) {
      await sendApiResponse(request.response, 500, {
        'error': {
          'code': 'internal_error',
          'message': 'Request could not be completed.',
        },
      });
    }
  }

  Future<void> _admin(HttpRequest request, CareSession current) async {
    final parts = request.uri.pathSegments;
    if (parts.length == 4 && parts[3] == 'audit' && request.method == 'GET') {
      await _audit.handle(request);
      return;
    }
    if (parts.length == 5 &&
        parts[3] == 'backups' &&
        parts[4] == 'restore-status' &&
        request.method == 'GET') {
      await _backupHandler.status(request);
      return;
    }
    if (parts.length == 4 && parts[3] == 'backups' && request.method == 'GET') {
      await _backupHandler.export(request, current);
      return;
    }
    if (parts.length == 5 &&
        parts[3] == 'backups' &&
        parts[4] == 'restore' &&
        request.method == 'POST') {
      await _backupHandler.restore(request, current);
      return;
    }
    if (await _accountAdministration.handle(request, current)) return;
    throw const ApiProblem(
      404,
      'not_found',
      'Unknown administrator operation.',
    );
  }
}
