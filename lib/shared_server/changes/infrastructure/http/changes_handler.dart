import 'dart:convert';
import 'dart:io';

import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/changes/application/committed_changes.dart';
import 'package:terramanager/shared_server/collection/application/collection_operation_gate.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

class ChangesHandler {
  const ChangesHandler(this.changes, this.accounts, this.gate);
  final CommittedChanges changes;
  final AccountStore accounts;
  final CollectionOperationGate gate;

  String cursor(CareSession current) => changes.cursor(
    accountKey: '${current.account.id}.${current.account.auditId}',
    role: current.account.role.name,
    preferencesRevision: accounts.preferencesRevision(current.account.id),
  );

  Future<void> handle(HttpRequest request, CareSession current) async {
    if (gate.exclusive) {
      throw const ApiProblem(
        503,
        'restore_in_progress',
        'The shared collection is temporarily unavailable.',
      );
    }
    final parameters = request.uri.queryParametersAll;
    if (parameters.keys.any((key) => key != 'since') ||
        parameters['since'] != null && parameters['since']!.length != 1) {
      throw const ApiProblem(
        400,
        'invalid_data',
        'Expected one optional since cursor.',
      );
    }
    final body = changes.query(
      accountKey: '${current.account.id}.${current.account.auditId}',
      role: current.account.role.name,
      preferencesRevision: accounts.preferencesRevision(current.account.id),
      since: parameters['since']?.single,
    );
    final etag = '"${body['cursor']}"';
    final response = request.response;
    response.headers.set(HttpHeaders.etagHeader, etag);
    response.headers.set(CommittedChanges.cursorHeader, body['cursor']!);
    response.headers.set(HttpHeaders.cacheControlHeader, 'private, no-store');
    response.headers.set(HttpHeaders.varyHeader, 'Cookie');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    final validators = request.headers[HttpHeaders.ifNoneMatchHeader]?.join(
      ',',
    );
    final matches =
        validators?.split(',').any((value) {
          final tag = value.trim();
          return tag == '*' ||
              (tag.startsWith('W/') ? tag.substring(2) : tag) == etag;
        }) ??
        false;
    if (body['reset'] == false && matches) {
      response.statusCode = HttpStatus.notModified;
      await response.close();
      return;
    }
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
