import 'dart:async';

/// Blocks new collection requests while an export or restore owns the database.
/// Existing mutations drain before the exclusive operation begins.
class CollectionOperationGate {
  bool _exclusive = false;
  int _activeMutations = 0;
  int _generation = 0;
  Completer<void>? _drained;

  int get generation => _generation;
  bool get exclusive => _exclusive;

  bool enterMutation() {
    if (_exclusive) return false;
    _activeMutations++;
    // Conservative invalidation also covers a request whose reply is lost.
    _generation++;
    return true;
  }

  void leaveMutation() {
    _activeMutations--;
    if (_activeMutations == 0) {
      _drained?.complete();
      _drained = null;
    }
  }

  Future<bool> enterExclusive() async {
    if (_exclusive) return false;
    _exclusive = true;
    if (_activeMutations != 0) {
      _drained ??= Completer<void>();
      await _drained!.future;
    }
    return true;
  }

  void leaveExclusive() => _exclusive = false;
}
