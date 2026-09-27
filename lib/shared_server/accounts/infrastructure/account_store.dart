import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:terramanager/shared_server/accounts/domain/care_account.dart';
import 'package:terramanager/shared_server/audit/application/audit_query.dart';
import 'package:terramanager/shared_server/audit/domain/audit_event.dart';
import 'package:terramanager/shared_server/audit/infrastructure/audit_schema.dart';
import 'package:terramanager/shared_server/authentication/domain/care_session.dart';
import 'package:terramanager/shared_server/authentication/infrastructure/password_hasher.dart';
import 'package:terramanager/shared_server/settings/application/account_preferences.dart';
import 'package:uuid/uuid.dart';

export 'package:terramanager/shared_server/accounts/domain/care_account.dart';
export 'package:terramanager/shared_server/authentication/domain/care_session.dart';

/// Server-only credentials. This file is deliberately outside the portable
/// collection backup and must be persisted and protected with the server data.
class AccountStore {
  static const sessionLifetime = Duration(hours: 12);

  final Database _db;
  final Random _random = Random.secure();

  AccountStore._(this._db);

  static Future<AccountStore> open(File file) async {
    await file.parent.create(recursive: true);
    final db = sqlite3.open(file.path);
    try {
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id INTEGER PRIMARY KEY,
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          role TEXT NOT NULL CHECK (role IN ('administrator', 'caregiver')),
          active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1))
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
          token_hash TEXT PRIMARY KEY,
          account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
          csrf_token TEXT NOT NULL,
          expires_at INTEGER NOT NULL
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS sessions_expires ON sessions(expires_at)',
      );
      db.execute('''
        CREATE TABLE IF NOT EXISTS account_preferences (
          account_id INTEGER PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
          preferences_json TEXT NOT NULL
        )
      ''');
      if (!db
          .select('PRAGMA table_info(accounts)')
          .any((row) => row['name'] == 'audit_id')) {
        db.execute('ALTER TABLE accounts ADD COLUMN audit_id TEXT');
      }
      db.execute(
        "UPDATE accounts SET audit_id = lower(hex(randomblob(16))) WHERE audit_id IS NULL",
      );
      db.execute(auditTableSql);
      db.execute(auditIndexSql);
      db.execute(auditReadIndexSql);
      db.execute('DELETE FROM shared_audit_events WHERE occurred_at < ?', [
        DateTime.now().toUtc().subtract(auditRetention).toIso8601String(),
      ]);
      return AccountStore._(db);
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  void close() => _db.close();

  Map<String, Object> preferences(int accountId) {
    final rows = _db.select(
      'SELECT preferences_json FROM account_preferences WHERE account_id = ?',
      [accountId],
    );
    return {
      ...defaultAccountPreferences,
      if (rows.isNotEmpty)
        ...validateAccountPreferences(
          jsonDecode(rows.single['preferences_json'] as String)
              as Map<String, dynamic>,
        ),
    };
  }

  Map<String, Object> updatePreferences(
    int accountId,
    Map<String, dynamic> patch,
  ) {
    final valid = validateAccountPreferences(patch);
    // Synchronous SQLite read/merge/write cannot interleave with another request.
    final updated = {...preferences(accountId), ...valid};
    _db.execute(
      'INSERT INTO account_preferences (account_id, preferences_json) VALUES (?, ?) '
      'ON CONFLICT(account_id) DO UPDATE SET preferences_json = excluded.preferences_json',
      [accountId, jsonEncode(updated)],
    );
    return updated;
  }

  List<Map<String, Object?>> readAudit(AuditQuery query) => [
    for (final row in _db.select(query.sql, query.values('account')))
      auditMetadata(row, 'account'),
  ];

  bool get hasAccounts =>
      (_db.select('SELECT COUNT(*) AS n FROM accounts').single['n'] as int) > 0;

  static String normalizeUsername(String value) {
    final username = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$').hasMatch(username)) {
      throw const FormatException(
        'Username must be 3–64 ASCII letters, digits, dots, underscores or dashes.',
      );
    }
    return username;
  }

  static void validatePassword(String password) {
    if (password.length < 12 || utf8.encode(password).length > 1024) {
      throw const FormatException('Password must be 12–1024 UTF-8 bytes.');
    }
  }

  Future<CareAccount> createInitialAdministrator(
    String username,
    String password,
  ) async {
    if (hasAccounts) throw StateError('An account already exists.');
    return createAccount(
      username,
      password,
      CareRole.administrator,
      initial: true,
    );
  }

  Future<CareAccount> createAccount(
    String username,
    String password,
    CareRole role, {
    bool initial = false,
    CareAccount? actor,
  }) async {
    username = normalizeUsername(username);
    validatePassword(password);
    final hash = await PasswordHasher.hash(password, _randomBytes(16));
    return _transaction(() {
      _checkActor(actor);
      if (initial ? hasAccounts : !hasAccounts) {
        throw StateError('Initial administrator must be created first.');
      }
      _db.execute(
        'INSERT INTO accounts(username, password_hash, role, audit_id) VALUES (?, ?, ?, ?)',
        [username, hash, role.name, const Uuid().v4()],
      );
      final account = accountById(_db.lastInsertRowId)!;
      _recordAudit(
        AuditEvent(
          actor:
              actor?.auditActor ??
              const AuditActor(
                'server-bootstrap',
                'Server administrator tool',
                'system',
              ),
          action: 'account.create',
          recordType: 'account',
          recordId: account.auditId,
          outcome: 'success',
          statusCode: 201,
        ),
      );
      return account;
    });
  }

  List<CareAccount> listAccounts() => _db
      .select(
        'SELECT id, username, role, active, audit_id FROM accounts ORDER BY username',
      )
      .map(_account)
      .toList(growable: false);

  CareAccount? accountById(int id) {
    final rows = _db.select(
      'SELECT id, username, role, active, audit_id FROM accounts WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : _account(rows.single);
  }

  Future<CareAccount?> authenticate(String username, String password) async {
    final rows = _db.select(
      'SELECT id, username, role, active, audit_id, password_hash FROM accounts WHERE username = ?',
      [username.trim().toLowerCase()],
    );
    // Verify a dummy hash too, so unknown users are not a cheap oracle.
    final stored = rows.isEmpty
        ? PasswordHasher.dummyHash
        : rows.single['password_hash'] as String;
    final valid = await PasswordHasher.verify(password, stored);
    return valid && rows.isNotEmpty && rows.single['active'] == 1
        ? _account(rows.single)
        : null;
  }

  CareSession createSession(CareAccount account, {DateTime? now}) {
    final instant = now ?? DateTime.now().toUtc();
    final token = base64Url.encode(_randomBytes(32)).replaceAll('=', '');
    final csrf = base64Url.encode(_randomBytes(32)).replaceAll('=', '');
    final expiry = instant.add(sessionLifetime);
    _db.execute(
      'INSERT INTO sessions(token_hash, account_id, csrf_token, expires_at) VALUES (?, ?, ?, ?)',
      [_tokenHash(token), account.id, csrf, expiry.millisecondsSinceEpoch],
    );
    return CareSession(token, csrf, expiry, account);
  }

  CareSession? findSession(String token, {DateTime? now}) {
    if (token.length != 43 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(token)) {
      return null;
    }
    final rows = _db.select(
      '''
      SELECT a.id, a.username, a.role, a.active, a.audit_id, s.csrf_token, s.expires_at
      FROM sessions s JOIN accounts a ON a.id = s.account_id
      WHERE s.token_hash = ?
    ''',
      [_tokenHash(token)],
    );
    if (rows.isEmpty || rows.single['active'] != 1) return null;
    final row = rows.single;
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      row['expires_at'] as int,
      isUtc: true,
    );
    if (!expiry.isAfter(now ?? DateTime.now().toUtc())) return null;
    return CareSession(
      token,
      row['csrf_token'] as String,
      expiry,
      _account(row),
    );
  }

  void revokeSession(String token) {
    if (token.length == 43) {
      _db.execute('DELETE FROM sessions WHERE token_hash = ?', [
        _tokenHash(token),
      ]);
    }
  }

  Future<CareAccount> updateAccount(
    int id, {
    String? username,
    String? expectedAuditId,
    CareRole? role,
    bool? active,
    String? password,
    CareAccount? actor,
  }) async {
    final normalizedName = username == null
        ? null
        : normalizeUsername(username);
    if (password != null) validatePassword(password);
    final hash = password == null
        ? null
        : await PasswordHasher.hash(password, _randomBytes(16));
    return _transaction(() {
      _checkActor(actor);
      // Re-read inside the transaction: hashing may have yielded to another
      // administrator request that changed this account's role or state.
      final current = accountById(id);
      if (current == null) throw StateError('Account not found.');
      if (expectedAuditId != null && current.auditId != expectedAuditId) {
        throw StateError('Account changed. Reload before trying again.');
      }
      if (current.role == CareRole.administrator &&
          current.active &&
          (role == CareRole.caregiver || active == false) &&
          _activeAdminCount() <= 1) {
        throw StateError('The last active administrator cannot be removed.');
      }
      _db.execute(
        '''
        UPDATE accounts SET username = ?, role = ?, active = ?,
          password_hash = COALESCE(?, password_hash) WHERE id = ?
      ''',
        [
          normalizedName ?? current.username,
          (role ?? current.role).name,
          (active ?? current.active) ? 1 : 0,
          hash,
          id,
        ],
      );
      if (normalizedName != null ||
          role != null ||
          active != null ||
          hash != null) {
        _db.execute('DELETE FROM sessions WHERE account_id = ?', [id]);
      }
      _recordAudit(
        AuditEvent(
          actor:
              actor?.auditActor ??
              const AuditActor(
                'server-bootstrap',
                'Server administrator tool',
                'system',
              ),
          action: 'account.update',
          recordType: 'account',
          recordId: current.auditId,
          outcome: 'success',
          statusCode: 200,
        ),
      );
      return accountById(id)!;
    });
  }

  void _checkActor(CareAccount? actor) {
    if (actor == null) return; // Trusted local administrator tooling.
    final current = accountById(actor.id);
    if (current == null ||
        current.auditId != actor.auditId ||
        !current.active ||
        current.role != CareRole.administrator) {
      throw StateError('Administrator access is no longer available.');
    }
  }

  void removeAccount(
    int id, {
    required CareAccount actor,
    String? expectedAuditId,
  }) {
    _transaction(() {
      _checkActor(actor);
      final current = accountById(id);
      if (current == null) throw StateError('Account not found.');
      if (expectedAuditId != null && current.auditId != expectedAuditId) {
        throw StateError('Account changed. Reload before trying again.');
      }
      if (current.active &&
          current.role == CareRole.administrator &&
          _activeAdminCount() <= 1) {
        throw StateError('The last active administrator cannot be removed.');
      }
      _recordAudit(
        AuditEvent(
          actor: actor.auditActor,
          action: 'account.delete',
          recordType: 'account',
          recordId: current.auditId,
          outcome: 'success',
          statusCode: 200,
        ),
      );
      // Session foreign keys cascade; audit metadata deliberately has no FK.
      _db.execute('DELETE FROM accounts WHERE id = ?', [id]);
    });
  }

  void recordRejectedAdministration(
    CareAccount actor,
    String action,
    int? accountId,
    int status,
  ) {
    _recordAudit(
      AuditEvent(
        actor: actor.auditActor,
        action: action,
        recordType: 'account',
        recordId: accountId == null ? null : accountById(accountId)?.auditId,
        outcome: 'rejected',
        statusCode: status,
      ),
    );
  }

  void _recordAudit(AuditEvent event) {
    _db.execute(auditInsertSql, event.sqlValues);
    _db.execute('DELETE FROM shared_audit_events WHERE occurred_at < ?', [
      DateTime.now().toUtc().subtract(auditRetention).toIso8601String(),
    ]);
  }

  int _activeAdminCount() =>
      _db
              .select(
                "SELECT COUNT(*) AS n FROM accounts WHERE role = 'administrator' AND active = 1",
              )
              .single['n']
          as int;

  T _transaction<T>(T Function() action) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));

  static String _tokenHash(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  static CareAccount _account(Row row) => CareAccount(
    row['id'] as int,
    row['username'] as String,
    CareRole.values.byName(row['role'] as String),
    row['active'] == 1,
    row['audit_id'] as String,
  );
}
