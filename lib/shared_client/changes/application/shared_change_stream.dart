import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';
import 'package:terramanager/shared_client/changes/domain/shared_event_source_port.dart';
import 'package:terramanager/shared_client/changes/infrastructure/api/shared_changes_api.dart';

enum SharedStreamState {
  unsupported,
  closed,
  connecting,
  open,
  failed,
  authRequired,
}

/// Owns at most one source. Received IDs describe transport delivery only.
/// Reconnection/backoff and fallback scheduling are deliberately external.
class SharedChangeStream extends ChangeNotifier {
  SharedChangeStream(this.url, this.source)
    : _state = source.supported
          ? SharedStreamState.closed
          : SharedStreamState.unsupported {
    if (url.path != '/api/v1/changes/events' ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment) {
      throw ArgumentError('Invalid change stream URL.');
    }
  }
  final Uri url;
  final SharedEventSourcePort source;
  SharedStreamState _state;
  SharedStreamState get state => _state;
  String? _lastReceivedId;
  String? get lastReceivedId => _lastReceivedId;
  SharedChangeQuery? _hint;
  SharedChangeQuery? get hint => _hint;
  int _activityVersion = 0;
  int get activityVersion => _activityVersion;
  int _hintVersion = 0;
  int get hintVersion => _hintVersion;
  int _generation = 0;
  bool _disposed = false;

  void _setState(SharedStreamState state) {
    if (_disposed || state == _state) return;
    _state = state;
    notifyListeners();
  }

  void start() {
    if (_disposed ||
        !source.supported ||
        _state == SharedStreamState.connecting ||
        _state == SharedStreamState.open) {
      return;
    }
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    void fail(SharedStreamState state) {
      if (!current()) return;
      _generation++;
      source.close();
      _setState(state);
    }

    _setState(SharedStreamState.connecting);
    if (!current()) return; // A state observer may cancel during notification.
    try {
      source.open(
        url,
        onOpen: () {
          if (current()) _setState(SharedStreamState.open);
        },
        onError: () => fail(SharedStreamState.failed),
        onMessage: (event, data, id) {
          if (!current()) return;
          if (event == 'keepalive') {
            _activityVersion++;
            notifyListeners();
            return;
          }
          if (event == 'auth-required') {
            fail(SharedStreamState.authRequired);
            return;
          }
          if (event != 'changes') return;
          try {
            if (data.length > 64 * 1024 || id.isEmpty || id.length > 200) {
              throw const FormatException();
            }
            final body = jsonDecode(data);
            if (body is! Map<String, dynamic> ||
                body['cursor'] != id ||
                body['epoch'] is! String ||
                body['revision'] is! int ||
                body['preferencesRevision'] is! int ||
                body['reset'] is! bool ||
                body['preferencesChanged'] is! bool ||
                body['changes'] is! List) {
              throw const FormatException();
            }
            final hint = SharedChangeQuery(cursor: id, body: body);
            SharedInvalidation.fromQuery(
              hint,
            ); // Validate without applying data/cursor.
            _activityVersion++;
            _lastReceivedId = id;
            _hint = hint;
            _hintVersion++;
            notifyListeners();
          } catch (_) {
            fail(SharedStreamState.failed);
          }
        },
      );
    } catch (_) {
      fail(SharedStreamState.failed);
    }
  }

  void stop({bool clearReceived = false}) {
    if (_disposed) return;
    _generation++;
    source.close();
    if (clearReceived) {
      _lastReceivedId = null;
      _hint = null;
    }
    if (source.supported) _setState(SharedStreamState.closed);
  }

  @override
  void dispose() {
    stop(clearReceived: true);
    _disposed = true;
    super.dispose();
  }
}
