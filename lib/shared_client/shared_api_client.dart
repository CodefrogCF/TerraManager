import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// The shared client deliberately holds no collection data on disk.
class SharedApiClient extends ChangeNotifier {
  SharedApiClient(this.origin, this._client) {
    if (origin.scheme != 'https' &&
        !(origin.scheme == 'http' &&
            {'localhost', '127.0.0.1'}.contains(origin.host))) {
      throw ArgumentError.value(origin, 'origin', 'HTTPS is required.');
    }
  }

  final Uri origin;
  final http.Client _client;
  SharedSession? _session;
  bool _connected = false;
  Object? lastFailure;

  SharedSession? get session => _session;
  bool get connected => _connected;

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    notifyListeners();
  }

  Uri _url(String path) {
    if (!path.startsWith('/api/v1/') || path.contains('..')) {
      throw ArgumentError.value(path, 'path', 'Invalid API path.');
    }
    return origin.resolve(path);
  }

  Future<SharedSession?> restoreSession() async {
    try {
      final json = await _request('GET', '/api/v1/auth/session');
      return _session = SharedSession.fromJson(json);
    } on SharedApiException catch (error) {
      if (error.status == 401) {
        _session = null;
        return null;
      }
      rethrow;
    }
  }

  Future<SharedSession> login(String username, String password) async {
    final json = await _request(
      'POST',
      '/api/v1/auth/login',
      body: {'username': username, 'password': password},
      requiresSession: false,
    );
    return _session = SharedSession.fromJson(json);
  }

  Future<void> logout() async {
    await _request('POST', '/api/v1/auth/logout');
    _session = null;
  }

  Future<List<Map<String, dynamic>>> accounts() async =>
      _list(await _request('GET', '/api/v1/admin/accounts'), 'accounts');

  Future<Map<String, dynamic>> createAccount(
    String username,
    String password,
    String role,
  ) async => _object(
    await _request(
      'POST',
      '/api/v1/admin/accounts',
      body: {'username': username, 'password': password, 'role': role},
    ),
    'account',
  );

  Future<List<Map<String, dynamic>>> boxes() async =>
      _list(await _request('GET', '/api/v1/boxes'), 'boxes');

  Future<List<Map<String, dynamic>>> animals() async =>
      _list(await _request('GET', '/api/v1/animals'), 'animals');

  Future<List<Map<String, dynamic>>> reminders() async =>
      _list(await _request('GET', '/api/v1/reminders'), 'reminders');

  Future<Map<String, dynamic>> box(int id) async =>
      _object(await _request('GET', '/api/v1/boxes/$id'), 'box');

  Future<Map<String, dynamic>> boxByQrId(String qrId) async => _object(
    await _request('GET', '/api/v1/boxes/qr/${Uri.encodeComponent(qrId)}'),
    'box',
  );

  Future<Map<String, dynamic>> animal(int id) async =>
      _object(await _request('GET', '/api/v1/animals/$id'), 'animal');

  Future<Map<String, dynamic>> createBox(Map<String, dynamic> values) async =>
      _object(await _request('POST', '/api/v1/boxes', body: values), 'box');

  Future<Map<String, dynamic>> updateBox(
    int id,
    Map<String, dynamic> values,
    String expectedRevision,
  ) async => _object(
    await _request(
      'PATCH',
      '/api/v1/boxes/$id',
      body: {...values, 'expectedRevision': expectedRevision},
    ),
    'box',
  );

  Future<Map<String, dynamic>> archiveBox(
    int id,
    String reason,
    String? notes,
  ) async => _object(
    await _request(
      'POST',
      '/api/v1/boxes/$id/archive',
      body: {'reason': reason, 'archiveNotes': notes},
    ),
    'box',
  );

  Future<Map<String, dynamic>> restoreBox(int id) async => _object(
    await _request('POST', '/api/v1/boxes/$id/restore', body: {}),
    'box',
  );

  Future<Map<String, dynamic>> duplicateBox(int id, String? name) async =>
      _object(
        await _request(
          'POST',
          '/api/v1/boxes/$id/duplicate',
          body: {'name': name},
        ),
        'box',
      );

  Future<void> deleteBox(int id) async {
    await _request('DELETE', '/api/v1/boxes/$id');
  }

  Future<Map<String, dynamic>> createAnimal(
    Map<String, dynamic> values,
  ) async => _object(
    await _request('POST', '/api/v1/animals', body: values),
    'animal',
  );

  Future<Map<String, dynamic>> updateAnimal(
    int id,
    Map<String, dynamic> values,
    String expectedRevision,
  ) async => _object(
    await _request(
      'PUT',
      '/api/v1/animals/$id',
      body: {...values, 'expectedRevision': expectedRevision},
    ),
    'animal',
  );

  Future<Map<String, dynamic>> rehouseAnimal(
    int id,
    int boxId,
    String expectedRevision,
  ) async => _object(
    await _request(
      'POST',
      '/api/v1/animals/$id/move',
      body: {'boxId': boxId, 'expectedRevision': expectedRevision},
    ),
    'animal',
  );

  Future<Map<String, dynamic>> updateFeedingReminder(
    int animalId, {
    required String expectedRevision,
    required int? intervalDays,
    required DateTime? baseline,
  }) async => _object(
    await _request(
      'PUT',
      '/api/v1/animals/$animalId/feeding-reminder',
      body: {
        'expectedRevision': expectedRevision,
        'intervalDays': intervalDays,
        'baseline': baseline?.toUtc().toIso8601String(),
      },
    ),
    'animal',
  );

  Future<Map<String, dynamic>> archiveAnimal(
    int id,
    String reason,
    String? notes,
  ) async => _object(
    await _request(
      'POST',
      '/api/v1/animals/$id/archive',
      body: {'reason': reason, 'archiveNotes': notes},
    ),
    'animal',
  );

  Future<Map<String, dynamic>> restoreAnimal(int id, int boxId) async =>
      _object(
        await _request(
          'POST',
          '/api/v1/animals/$id/restore',
          body: {'boxId': boxId},
        ),
        'animal',
      );

  Future<Map<String, dynamic>> duplicateAnimal(
    int id,
    int boxId,
    String commonName,
  ) async => _object(
    await _request(
      'POST',
      '/api/v1/animals/$id/duplicate',
      body: {'boxId': boxId, 'commonName': commonName},
    ),
    'animal',
  );

  Future<void> deleteAnimal(int id) async {
    await _request('DELETE', '/api/v1/animals/$id');
  }

  Future<List<Map<String, dynamic>>> feedings(int animalId) async => _list(
    await _request('GET', '/api/v1/animals/$animalId/feedings'),
    'feedings',
  );

  Future<Map<String, dynamic>> createFeeding(
    int animalId,
    DateTime fedAt,
    String? notes, {
    String? requestId,
  }) async => (await createFeedings(
    animalIds: [animalId],
    fedAt: fedAt,
    notes: notes,
    requestId: requestId,
  )).single;

  Future<List<Map<String, dynamic>>> createFeedings({
    required List<int> animalIds,
    required DateTime fedAt,
    required String? notes,
    int? boxId,
    String? requestId,
  }) async {
    final body = <String, dynamic>{
      'animalIds': animalIds,
      'fedAt': fedAt.toUtc().toIso8601String(),
      'notes': notes,
    };
    if (boxId != null) {
      body['boxId'] = boxId;
    }
    return _list(
      await _request(
        'POST',
        '/api/v1/feedings',
        body: body,
        extraHeaders: {'Idempotency-Key': requestId ?? const Uuid().v4()},
      ),
      'feedings',
    );
  }

  Future<List<Map<String, dynamic>>> weights(int animalId) async => _list(
    await _request('GET', '/api/v1/animals/$animalId/weights'),
    'weights',
  );

  Future<List<Map<String, dynamic>>> shedding(int animalId) async => _list(
    await _request('GET', '/api/v1/animals/$animalId/shedding'),
    'shedding',
  );

  Future<Map<String, dynamic>> updateFeeding(
    int id,
    DateTime fedAt,
    String? notes,
  ) async => _object(
    await _request(
      'PUT',
      '/api/v1/feedings/$id',
      body: {'fedAt': fedAt.toUtc().toIso8601String(), 'notes': notes},
    ),
    'feeding',
  );

  Future<void> deleteFeeding(int id) async {
    await _request('DELETE', '/api/v1/feedings/$id');
  }

  Future<Map<String, dynamic>> addWeight(
    int animalId,
    double grams,
    DateTime measuredAt,
  ) async => _object(
    await _request(
      'POST',
      '/api/v1/animals/$animalId/weights',
      body: {
        'weightGrams': grams,
        'measuredAt': measuredAt.toUtc().toIso8601String(),
      },
    ),
    'weight',
  );

  Future<Map<String, dynamic>> updateWeight(
    int animalId,
    int id,
    double grams,
    DateTime measuredAt,
  ) async => _object(
    await _request(
      'PUT',
      '/api/v1/animals/$animalId/weights/$id',
      body: {
        'weightGrams': grams,
        'measuredAt': measuredAt.toUtc().toIso8601String(),
      },
    ),
    'weight',
  );

  Future<void> deleteWeight(int animalId, int id) async {
    await _request('DELETE', '/api/v1/animals/$animalId/weights/$id');
  }

  Future<Map<String, dynamic>> addShedding(
    int animalId,
    DateTime shedAt,
    String? notes,
  ) async => _object(
    await _request(
      'POST',
      '/api/v1/animals/$animalId/shedding',
      body: {'shedAt': shedAt.toUtc().toIso8601String(), 'notes': notes},
    ),
    'shedding',
  );

  Future<Map<String, dynamic>> updateShedding(
    int animalId,
    int id,
    DateTime shedAt,
    String? notes,
  ) async => _object(
    await _request(
      'PUT',
      '/api/v1/animals/$animalId/shedding/$id',
      body: {'shedAt': shedAt.toUtc().toIso8601String(), 'notes': notes},
    ),
    'shedding',
  );

  Future<void> deleteShedding(int animalId, int id) async {
    await _request('DELETE', '/api/v1/animals/$animalId/shedding/$id');
  }

  Future<int> uploadMedia(
    String fileName,
    String mimeType,
    Uint8List bytes,
  ) async {
    final response = await _request(
      'POST',
      '/api/v1/media',
      body: {
        'fileName': fileName,
        'mimeType': mimeType,
        'dataBase64': base64Encode(bytes),
      },
    );
    final id = response['id'];
    if (id is int) return id;
    throw const SharedApiException(
      200,
      'invalid_response',
      'The server returned an invalid media ID.',
    );
  }

  Future<List<Map<String, dynamic>>> pictures(
    String kind,
    int recordId,
  ) async => _list(
    await _request('GET', '/api/v1/$kind/$recordId/pictures'),
    'pictures',
  );

  Future<Map<String, dynamic>> addPicture(
    String kind,
    int recordId,
    String fileName,
    String mimeType,
    Uint8List bytes,
  ) async => _object(
    await _request(
      'POST',
      '/api/v1/$kind/$recordId/pictures',
      body: {
        'fileName': fileName,
        'mimeType': mimeType,
        'dataBase64': base64Encode(bytes),
      },
    ),
    'picture',
  );

  Future<void> removePicture(String kind, int recordId, int mediaId) async {
    await _request('DELETE', '/api/v1/$kind/$recordId/pictures/$mediaId');
  }

  Future<void> setPrimaryPicture(String kind, int recordId, int mediaId) async {
    await _request(
      'POST',
      '/api/v1/$kind/$recordId/pictures/$mediaId/primary',
      body: {},
    );
  }

  Uri mediaUrl(int mediaId) => _url('/api/v1/media/$mediaId');

  Future<SharedBackupFile> exportBackup() async {
    final response = await _binaryRequest('GET', '/api/v1/admin/backups');
    final token = response.headers['x-safety-token'];
    if (token == null || token.isEmpty) {
      throw const SharedApiException(
        200,
        'invalid_response',
        'The safety backup token is missing.',
      );
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final fileName =
        RegExp(r'filename="([^"]+)"').firstMatch(disposition)?.group(1) ??
        'TerraManager_Shared_Backup.tmbackup';
    return SharedBackupFile(response.bodyBytes, fileName, token);
  }

  Future<void> restoreBackup(Uint8List bytes, String safetyToken) async {
    await _binaryRequest(
      'POST',
      '/api/v1/admin/backups/restore',
      bytes: bytes,
      timeout: const Duration(minutes: 10),
      extraHeaders: {
        'X-Safety-Token': safetyToken,
        'X-Restore-Confirmation': 'replace-shared-collection',
      },
    );
  }

  Future<http.Response> _binaryRequest(
    String method,
    String path, {
    Uint8List? bytes,
    Duration timeout = const Duration(minutes: 2),
    Map<String, String> extraHeaders = const {},
  }) async {
    final headers = <String, String>{...extraHeaders};
    if (bytes != null) {
      headers['Content-Type'] = 'application/vnd.terramanager.backup+zip';
      final token = _session?.csrfToken;
      if (token == null) {
        throw const SharedApiException(401, 'unauthorized', 'Sign in first.');
      }
      headers['X-CSRF-Token'] = token;
    }
    late final http.Response response;
    try {
      final request = http.Request(method, _url(path));
      request.headers.addAll(headers);
      if (bytes != null) request.bodyBytes = bytes;
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } catch (_) {
      _setConnected(false);
      throw const SharedConnectionException();
    }
    _setConnected(true);
    if (response.statusCode == 401) _session = null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final payload = jsonDecode(response.body);
        final error = payload is Map ? payload['error'] : null;
        throw SharedApiException(
          response.statusCode,
          error is Map && error['code'] is String
              ? error['code'] as String
              : 'request_failed',
          error is Map && error['message'] is String
              ? error['message'] as String
              : 'The request failed.',
        );
      } on SharedApiException {
        rethrow;
      } catch (_) {
        throw SharedApiException(
          response.statusCode,
          'request_failed',
          'The request failed.',
        );
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requiresSession = true,
    Map<String, String> extraHeaders = const {},
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    headers.addAll(extraHeaders);
    if (!{'GET', 'HEAD'}.contains(method)) lastFailure = null;
    if (body != null) headers['Content-Type'] = 'application/json';
    if (requiresSession && !{'GET', 'HEAD'}.contains(method)) {
      final csrfToken = _session?.csrfToken;
      if (csrfToken == null) {
        throw const SharedApiException(401, 'unauthorized', 'Sign in first.');
      }
      headers['X-CSRF-Token'] = csrfToken;
    }

    late final http.Response response;
    try {
      final request = http.Request(method, _url(path));
      request.headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      _setConnected(false);
      lastFailure = const SharedConnectionException();
      throw lastFailure!;
    }
    _setConnected(true);

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      json = decoded;
    } catch (_) {
      final failure = SharedApiException(
        response.statusCode,
        'invalid_response',
        'The server returned an invalid response.',
      );
      lastFailure = failure;
      throw failure;
    }

    if (response.statusCode == 401 && requiresSession) _session = null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final failure = SharedApiException(
        response.statusCode,
        error is Map && error['code'] is String
            ? error['code'] as String
            : 'request_failed',
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'The request failed.',
      );
      lastFailure = failure;
      throw failure;
    }
    return json;
  }

  static Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    throw const SharedApiException(
      200,
      'invalid_response',
      'The server returned an invalid record.',
    );
  }

  static List<Map<String, dynamic>> _list(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is List &&
        value.every((entry) => entry is Map<String, dynamic>)) {
      return value.cast<Map<String, dynamic>>();
    }
    throw const SharedApiException(
      200,
      'invalid_response',
      'The server returned an invalid collection.',
    );
  }

  void close() {
    _client.close();
    dispose();
  }
}

class SharedSession {
  const SharedSession({
    required this.username,
    required this.role,
    required this.csrfToken,
  });

  final String username;
  final String role;
  final String csrfToken;

  factory SharedSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final csrf = json['csrfToken'];
    if (user is! Map ||
        user['username'] is! String ||
        user['role'] is! String ||
        csrf is! String) {
      throw const SharedApiException(
        200,
        'invalid_response',
        'The server returned an invalid session.',
      );
    }
    return SharedSession(
      username: user['username'] as String,
      role: user['role'] as String,
      csrfToken: csrf,
    );
  }
}

class SharedBackupFile {
  const SharedBackupFile(this.bytes, this.fileName, this.safetyToken);

  final Uint8List bytes;
  final String fileName;
  final String safetyToken;
}

class SharedApiException implements Exception {
  const SharedApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;

  @override
  String toString() => message;
}

class SharedConnectionException implements Exception {
  const SharedConnectionException();

  @override
  String toString() => 'The shared server is unreachable.';
}
