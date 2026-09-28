import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_server/accounts/infrastructure/account_store.dart';
import 'package:terramanager/shared_server/authentication/application/authentication_operations.dart';
import 'package:terramanager/shared_server/authentication/application/login_attempt_limiter.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

void main() {
  test(
    'login operation rejects concurrent requests while verification waits',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tm-login-limit-',
      );
      final accounts = await AccountStore.open(
        File('${directory.path}${Platform.pathSeparator}accounts.sqlite'),
      );
      final verification = Completer<CareAccount?>();
      final operations = AuthenticationOperations(
        accounts,
        authenticate: (username, password) {
          expect(username, 'keeper');
          return verification.future;
        },
      );

      Future<int> status(String username) async {
        try {
          await operations.login(username, 'wrong');
          return 200;
        } on ApiProblem catch (error) {
          return error.status;
        }
      }

      try {
        final inFlight = [for (var i = 0; i < 4; i++) status('Keeper')];
        final overflow = await Future.wait([
          status('keeper'),
          status('keeper'),
        ]);
        expect(overflow, [429, 429]);
        verification.complete(null);
        expect(await Future.wait(inFlight), everyElement(401));
        expect(await status('keeper'), 401);
        expect(await status('keeper'), 429);
      } finally {
        accounts.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('simultaneous requests reserve capacity before verification', () {
    final limiter = LoginAttemptLimiter();
    final active = [
      for (var i = 0; i < LoginAttemptLimiter.maxConcurrentVerifications; i++)
        limiter.reserve('keeper'),
    ];
    expect(active, everyElement(isNotNull));
    expect(limiter.reserve('keeper'), isNull);
    expect(limiter.reserve('another'), isNull);

    active.first!.failed();
    final fifth = limiter.reserve('keeper');
    expect(fifth, isNotNull);
    expect(limiter.reserve('keeper'), isNull);
    for (final attempt in active.skip(1)) {
      attempt!.failed();
    }
    fifth!.failed();

    // One account's failed attempts do not use up another account's window.
    final other = limiter.reserve('another');
    expect(other, isNotNull);
    other!.failed();
  });

  test('distinct names cannot evict a blocked account', () {
    final limiter = LoginAttemptLimiter();
    for (var i = 0; i < LoginAttemptLimiter.maxAttemptsPerAccount; i++) {
      limiter.reserve('target')!.failed();
    }
    for (var i = 0; i < LoginAttemptLimiter.maxTrackedAccounts - 1; i++) {
      limiter.reserve('other$i')!.failed();
    }

    expect(limiter.reserve('target'), isNull);
    expect(limiter.reserve('new-name'), isNull);
    final existing = limiter.reserve('other0');
    expect(existing, isNotNull);
    existing!.failed();
    expect(limiter.reserve('target'), isNull);
  });

  test('expired attempts free capacity and success clears only that name', () {
    var now = DateTime.utc(2026, 1, 1);
    final limiter = LoginAttemptLimiter(now: () => now);
    for (var i = 0; i < LoginAttemptLimiter.maxAttemptsPerAccount; i++) {
      limiter.reserve('keeper')!.failed();
    }
    expect(limiter.reserve('keeper'), isNull);
    now = now.add(LoginAttemptLimiter.window);
    final renewed = limiter.reserve('keeper');
    expect(renewed, isNotNull);
    renewed!.succeeded();
    final afterSuccess = limiter.reserve('keeper');
    expect(afterSuccess, isNotNull);
    afterSuccess!.abort();
    for (var i = 0; i < LoginAttemptLimiter.maxAttemptsPerAccount; i++) {
      limiter.reserve('keeper')!.failed();
    }
    expect(limiter.reserve('keeper'), isNull);
  });
}
