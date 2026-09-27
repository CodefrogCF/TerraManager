import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

Future<Uint8List> readBackupBody(HttpRequest request) async {
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
  final builder = BytesBuilder(copy: false);
  await for (final chunk in request) {
    builder.add(chunk);
    if (builder.length > maxBytes) {
      throw const ApiProblem(413, 'too_large', 'Backup exceeds 256 MiB.');
    }
  }
  return builder.takeBytes();
}
