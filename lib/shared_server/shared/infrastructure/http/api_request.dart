import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:terramanager/features/backup/application/encrypted_backup_container.dart';
import 'package:terramanager/shared_server/shared/application/api_input.dart';

int parseRecordId(String raw) {
  final id = int.tryParse(raw);
  if (id == null || id < 1) {
    throw const ApiProblem(400, 'invalid_data', 'Invalid record ID.');
  }
  return id;
}

Future<ApiInput> readCollectionBody(
  HttpRequest request, {
  int maxBytes = 256 * 1024,
}) async {
  if (request.headers.contentType?.mimeType != 'application/json') {
    throw const ApiProblem(
      415,
      'unsupported_media_type',
      'Content-Type must be application/json.',
    );
  }
  final builder = BytesBuilder(copy: false);
  await for (final part in request) {
    builder.add(part);
    if (builder.length > maxBytes) {
      throw const ApiProblem(413, 'too_large', 'Request body is too large.');
    }
  }
  final String body;
  try {
    body = utf8.decode(builder.takeBytes());
  } on FormatException {
    throw const ApiProblem(400, 'invalid_json', 'Expected UTF-8 JSON.');
  }
  return ApiInput.decode(body);
}

Future<ApiInput> readAccountBody(HttpRequest request) async {
  if (request.headers.contentType?.mimeType != 'application/json') {
    throw const ApiProblem(
      415,
      'unsupported_media_type',
      'Content-Type must be application/json.',
    );
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in request) {
    builder.add(chunk);
    if (builder.length > 16384) {
      throw const ApiProblem(413, 'too_large', 'Request body is too large.');
    }
  }
  try {
    return ApiInput.decode(utf8.decode(builder.takeBytes()));
  } on FormatException {
    throw const ApiProblem(400, 'invalid_json', 'Expected UTF-8 JSON.');
  }
}

/// The restore endpoint receives a plain ZIP, but its temporary file contains
/// only authenticated ciphertext. The caller keeps [password] in memory until
/// validation and replacement have finished.
Future<void> writeEncryptedBackupBodyToFile(
  HttpRequest request,
  File destination, {
  required String password,
}) async {
  if (request.headers.contentType?.mimeType !=
      'application/vnd.terramanager.backup+zip') {
    throw const ApiProblem(
      415,
      'unsupported_media_type',
      'Expected a TerraManager backup archive.',
    );
  }
  const maxBytes = 256 * 1024 * 1024;
  if (request.contentLength > maxBytes) {
    throw const ApiProblem(413, 'too_large', 'Backup exceeds 256 MiB.');
  }
  await writeBoundedBackupStreamToEncryptedFile(
    request,
    destination,
    password: password,
    maxBytes: maxBytes,
  );
}

Future<void> writeBoundedBackupStreamToEncryptedFile(
  Stream<List<int>> chunks,
  File destination, {
  required String password,
  required int maxBytes,
}) async {
  final output = OutputFileStream(destination.path);
  EncryptedBackupOutputStream? encrypted;
  try {
    encrypted = await EncryptedBackupContainer.newOutput(
      output,
      password: password,
    );
    var length = 0;
    await for (final chunk in chunks) {
      length += chunk.length;
      if (length > maxBytes) {
        throw const ApiProblem(413, 'too_large', 'Backup exceeds 256 MiB.');
      }
      encrypted.writeBytes(chunk);
    }
    encrypted.finish();
    await output.close();
  } catch (_) {
    try {
      await output.close();
    } catch (_) {}
    try {
      await destination.delete();
    } catch (_) {}
    rethrow;
  } finally {
    encrypted?.dispose();
  }
}
