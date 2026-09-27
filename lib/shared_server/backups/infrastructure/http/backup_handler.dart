import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/backups/application/shared_backup_operations.dart';
import 'package:terramanager/shared_server/backups/application/shared_portable_backups.dart';
import 'package:terramanager/shared_server/collection/application/collection_operation_gate.dart';
import 'package:terramanager/shared_server/collection/infrastructure/http/care_api.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_request.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_response.dart';

class BackupHandler {
  BackupHandler(AppDatabase database, this._care, this._gate)
    : _backups = SharedPortableBackups(database) {
    operations = SharedBackupOperations(database, _backups);
  }
  final CareApi _care;
  final CollectionOperationGate _gate;
  final SharedPortableBackups _backups;
  late final SharedBackupOperations operations;
  final Map<String, _SafetyGrant> _safetyGrants = {};
  Future<void> status(HttpRequest request) async {
    if (!await _gate.enterExclusive()) {
      throw const ApiProblem(
        503,
        'restore_in_progress',
        'The shared collection is temporarily unavailable.',
      );
    }
    try {
      await sendApiResponse(request.response, 200, {
        'safetyBackupRequired': !await _backups.isEmpty(),
      });
    } finally {
      _gate.leaveExclusive();
    }
    return;
  }

  Future<void> export(HttpRequest request, CareSession current) async {
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

  Future<void> restore(HttpRequest request, CareSession current) async {
    if (request.headers.value('X-Restore-Confirmation') !=
        'replace-shared-collection') {
      throw const ApiProblem(
        400,
        'confirmation_required',
        'Explicit restore confirmation is required.',
      );
    }
    final grant = _safetyGrants[current.token];
    bool validGrant() =>
        grant != null &&
        grant.token == request.headers.value('X-Safety-Token') &&
        !DateTime.now().toUtc().isAfter(grant.expiresAt);
    if (!validGrant() && !await _backups.isEmpty()) {
      throw const ApiProblem(
        409,
        'safety_backup_required',
        'Download a current safety backup before restoring.',
      );
    }
    final bytes = await readBackupBody(request);
    final validated = _backups.validate(
      bytes,
      legacyTimeZone: request.headers.value('X-Backup-Time-Zone'),
    );
    if (!await _gate.enterExclusive()) {
      throw const ApiProblem(
        503,
        'restore_in_progress',
        'The shared collection is temporarily unavailable.',
      );
    }
    try {
      // The upload can take minutes. Recheck after existing writes have drained
      // and while the gate excludes new writes through transactional replacement.
      if (!await _backups.isEmpty()) {
        if (!validGrant()) {
          throw const ApiProblem(
            409,
            'safety_backup_required',
            'Download a current safety backup before restoring.',
          );
        }
        if (grant!.generation != _gate.generation) {
          throw const ApiProblem(
            409,
            'safety_backup_stale',
            'The collection changed. Download a new safety backup.',
          );
        }
      }
      final reply = await operations.restore(validated, current.account);
      _care.clearRequestCache();
      _safetyGrants.clear();
      await sendApiResponse(request.response, reply.status, reply.body!);
    } finally {
      _gate.leaveExclusive();
    }
  }
}

class _SafetyGrant {
  const _SafetyGrant(this.token, this.generation, this.expiresAt);

  final String token;
  final int generation;
  final DateTime expiresAt;
}
