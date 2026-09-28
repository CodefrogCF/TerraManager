/// Bounds password verification work and failed login attempts per account name.
///
/// The account name is deliberately used instead of a forwarded client address:
/// the bundled reverse proxy gives all clients the same socket address, while
/// client-supplied forwarding headers cannot be trusted here.
class LoginAttemptLimiter {
  LoginAttemptLimiter({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const window = Duration(minutes: 5);
  static const maxAttemptsPerAccount = 5;
  static const maxTrackedAccounts = 1000;
  static const maxConcurrentVerifications = 4;

  final DateTime Function() _now;
  final Map<String, List<_Attempt>> _attempts = {};
  int _activeVerifications = 0;

  /// Returns null when the account or server-wide verification budget is full.
  /// Reserving synchronously, before password verification begins, closes the
  /// gap through which simultaneous requests could all pass the same check.
  LoginAttemptLease? reserve(String username) {
    final now = _now().toUtc();
    _attempts.removeWhere((_, attempts) {
      attempts.removeWhere((attempt) => now.difference(attempt.at) >= window);
      return attempts.isEmpty;
    });

    final accountAttempts = _attempts[username];
    if ((accountAttempts?.length ?? 0) >= maxAttemptsPerAccount ||
        _activeVerifications >= maxConcurrentVerifications ||
        (accountAttempts == null && _attempts.length >= maxTrackedAccounts)) {
      return null;
    }

    final attempt = _Attempt(now);
    _attempts.putIfAbsent(username, () => []).add(attempt);
    _activeVerifications++;
    return LoginAttemptLease._(this, username, attempt);
  }

  void _finish(LoginAttemptLease lease, _AttemptResult result) {
    if (lease._finished) return;
    lease._finished = true;
    _activeVerifications--;
    if (result == _AttemptResult.success) {
      _attempts.remove(lease._username);
    } else if (result == _AttemptResult.aborted) {
      final attempts = _attempts[lease._username];
      attempts?.remove(lease._attempt);
      if (attempts != null && attempts.isEmpty) {
        _attempts.remove(lease._username);
      }
    }
    // A failed credential check keeps its reservation until the window ends.
  }
}

class _Attempt {
  _Attempt(this.at);
  final DateTime at;
}

enum _AttemptResult { success, failure, aborted }

class LoginAttemptLease {
  LoginAttemptLease._(this._limiter, this._username, this._attempt);

  final LoginAttemptLimiter _limiter;
  final String _username;
  final _Attempt _attempt;
  bool _finished = false;

  void succeeded() => _limiter._finish(this, _AttemptResult.success);
  void failed() => _limiter._finish(this, _AttemptResult.failure);
  void abort() => _limiter._finish(this, _AttemptResult.aborted);
}
