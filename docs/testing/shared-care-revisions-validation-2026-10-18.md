# Committed revision API validation (Issue #226), 2026-10-18

## Delivered scope

The [change contract](../shared-care-change-contract.md) is implemented in an
isolated copy based on ca8bb832a6384d73bb27cb2634c1fe1242d08dd9 plus the operator's
working files. The primary source files were not edited. Delivery is a ZIP of
changed/new repository-relative source, tests and documentation.

The private account-preferences table gains a revision column; legacy values
survive migration. The collection Drift schema, portable format, device
permissions and dependencies are unchanged. pubspec.lock matches the baseline.

## Executed checks

- Complete `flutter analyze --no-pub`: no issues found.
- Forty-three focused/regression Flutter tests: all passed.
- `flutter build web --no-pub`: succeeded, including the Wasm dry run.
- Native Windows server CLI bundle: built successfully with its SQLite asset.
- ZIP paths, contents, integrity and SHA-256 checked separately in delivery metadata.

The Flutter tests comprise:

```bash
flutter test --no-pub \
  test/shared_server/committed_changes_test.dart \
  test/shared_server/shared_changes_test.dart \
  test/shared_client/shared_changes_api_test.dart \
  test/shared_server/shared_audit_log_test.dart \
  test/shared_server/shared_server_auth_test.dart \
  test/shared_server/collection_operation_gate_test.dart \
  test/shared_client/shared_api_client_test.dart
```

Coverage includes commit visibility from an independent SQLite connection,
in-flight read cursor fences, concurrent mutations, bounded replay/reset,
grouped and idempotent Feedings, failed audit rollback, history/media lifecycle,
primary-picture changes through metadata, audience filtering, private preference
coalescing/persistence/migration, bodyless HTTP 304 and successful/failed restore.
Existing authentication, audit, gate and client behavior also passed regression.

The native build used `dart build cli --target=bin/shared_server.dart` with a
private output directory, producing a bundle with SQLite's required native asset.

## Environment and limits

Checks used the existing isolated Flutter 3.47.2 / Dart 3.13.2 toolchain on
Windows. The current server Dockerfile pins Dart 3.13.4; the new source has not
yet been rebuilt or run on the operator's ARM64 Pi.

Offline Pub resolution populated the package graph from the existing cache.
Flutter's Windows desktop plugin setup reported the host's symlink/developer-mode
requirement; the completed checks used `--no-pub` against the resolved graph.
No system developer-mode setting or global package source was patched.

The complete application test suite, Android packages and Windows desktop app
were not run/built for this delivery. The focused tests, complete analysis,
browser build and native server build above are the executed validation scope.

The current UI still uses its existing refresh behavior. Controller integration
is #227, production EventSource delivery is #228, connection/recovery policy is
#229 and real Flutter/device performance acceptance is #230. This API delivery
does not turn the earlier laboratory SSE timings into production measurements.
