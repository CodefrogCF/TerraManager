import 'dart:async';
import 'dart:io';

import 'package:terramanager/shared_server/authentication/infrastructure/http/session_authenticator.dart';
import 'package:terramanager/shared_server/collection/application/collection_operation_gate.dart';
import 'package:terramanager/shared_server/collection/infrastructure/http/care_api.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';
import 'package:terramanager/shared_server/shared/infrastructure/http/api_response.dart';

class CollectionHandler {
  const CollectionHandler(this._care, this.sessions, this._gate);
  final CareApi _care;
  final SessionAuthenticator sessions;
  final CollectionOperationGate _gate;
  Future<void> handle(HttpRequest request) async {
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
        await sendApiResponse(request.response, 503, {
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
      await sendApiResponse(request.response, 503, {
        'error': {
          'code': 'restore_in_progress',
          'message': 'The shared collection is temporarily unavailable.',
        },
      });
      return;
    }
    await _care.handle(request);
  }
}
