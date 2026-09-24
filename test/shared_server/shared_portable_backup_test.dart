import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/core/database/app_database.dart';
import 'package:terramanager/core/database/repositories/box_repository.dart';
import 'package:terramanager/core/database/repositories/picture_gallery_repository.dart';
import 'package:terramanager/features/backup/application/backup_export_service.dart';
import 'package:terramanager/features/backup/application/backup_validation_service.dart';
import 'package:terramanager/features/settings/app_accent.dart';
import 'package:terramanager/shared_server/account_store.dart';
import 'package:terramanager/shared_server/server_database.dart';
import 'package:terramanager/shared_server/shared_server_api.dart';

class _Reply {
  const _Reply(this.status, this.bytes, this.headers);
  final int status;
  final Uint8List bytes;
  final HttpHeaders headers;

  Map<String, dynamic> get json =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}

Future<_Reply> _call(
  HttpClient client,
  HttpServer server,
  String method,
  String path, {
  String? cookie,
  String? csrf,
  String? safetyToken,
  bool confirm = false,
  Map<String, Object?>? json,
  Uint8List? archive,
}) async {
  final request = await client.openUrl(
    method,
    Uri.parse('http://127.0.0.1:${server.port}$path'),
  );
  if (cookie != null) request.headers.set(HttpHeaders.cookieHeader, cookie);
  if (csrf != null) request.headers.set('X-CSRF-Token', csrf);
  if (safetyToken != null) request.headers.set('X-Safety-Token', safetyToken);
  if (confirm) {
    request.headers.set('X-Restore-Confirmation', 'replace-shared-collection');
  }
  if (json != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(json));
  }
  if (archive != null) {
    request.headers.contentType = ContentType.parse(
      'application/vnd.terramanager.backup+zip',
    );
    request.add(archive);
  }
  final response = await request.close();
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return _Reply(response.statusCode, builder.takeBytes(), response.headers);
}

void main() {
  test(
    'administrator backup preserves media and failed restore is atomic',
    () async {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final directory = await Directory.systemTemp.createTemp(
        'tm-shared-backup-',
      );
      final collectionFile = File('${directory.path}/collection.sqlite');
      final accounts = await AccountStore.open(
        File('${directory.path}/accounts.sqlite'),
      );
      final database = await openServerDatabase(collectionFile);
      final client = HttpClient();
      HttpServer? server;
      AppDatabase? source;
      try {
        await accounts.createInitialAdministrator(
          'admin',
          'a secure admin password 123',
        );
        await accounts.createAccount(
          'keeper',
          'a secure keeper password 123',
          CareRole.caregiver,
        );
        final originalId = await BoxRepository(database).createBox(
          'TM:BOX:11111111-1111-4111-8111-111111111111',
          name: 'Original',
        );
        await PictureGalleryRepository(database).addBoxPicture(
          boxId: originalId,
          fileName: 'original.png',
          mimeType: 'image/png',
          data: Uint8List.fromList([1, 2, 3]),
          capturedAt: DateTime.utc(2026, 1, 1),
        );
        server = await SharedServerApi(
          database: database,
          accounts: accounts,
          publicUrl: Uri.parse('http://127.0.0.1'),
        ).serve();
        final adminLogin = await _call(
          client,
          server,
          'POST',
          '/api/v1/auth/login',
          json: {
            'username': 'admin',
            'password': 'a secure admin password 123',
          },
        );
        final adminCookie = adminLogin.headers
            .value(HttpHeaders.setCookieHeader)!
            .split(';')
            .first;
        final csrf = adminLogin.json['csrfToken'] as String;
        final keeperLogin = await _call(
          client,
          server,
          'POST',
          '/api/v1/auth/login',
          json: {
            'username': 'keeper',
            'password': 'a secure keeper password 123',
          },
        );
        final keeperCookie = keeperLogin.headers
            .value(HttpHeaders.setCookieHeader)!
            .split(';')
            .first;

        expect(
          (await _call(
            client,
            server,
            'GET',
            '/api/v1/admin/backups',
            cookie: keeperCookie,
          )).status,
          403,
        );
        final exported = await _call(
          client,
          server,
          'GET',
          '/api/v1/admin/backups',
          cookie: adminCookie,
        );
        expect(exported.status, 200);
        expect(
          exported.headers.contentType!.mimeType,
          'application/vnd.terramanager.backup+zip',
        );
        final safetyToken = exported.headers.value('X-Safety-Token')!;
        final saved = BackupValidationService().validate(exported.bytes);
        expect(saved.settings.scope, 'collectionOnly');
        expect(saved.data.boxes.single.name, 'Original');
        expect(saved.mediaFileCount, 1);

        source = AppDatabase.test(NativeDatabase.memory());
        final importedId = await BoxRepository(source).createBox(
          'TM:BOX:22222222-2222-4222-8222-222222222222',
          name: 'Imported',
        );
        await PictureGalleryRepository(source).addBoxPicture(
          boxId: importedId,
          fileName: 'imported.png',
          mimeType: 'image/png',
          data: Uint8List.fromList([4, 5, 6]),
          capturedAt: DateTime.utc(2026, 1, 2),
        );
        final importFile = await BackupExportService(source).createBackup(
          appVersion: 'development',
          themeMode: ThemeMode.system,
          accent: AppAccent.green,
        );

        final missingConfirmation = await _call(
          client,
          server,
          'POST',
          '/api/v1/admin/backups/restore',
          cookie: adminCookie,
          csrf: csrf,
          safetyToken: safetyToken,
          archive: importFile.bytes,
        );
        expect(missingConfirmation.status, 400);
        final invalid = await _call(
          client,
          server,
          'POST',
          '/api/v1/admin/backups/restore',
          cookie: adminCookie,
          csrf: csrf,
          safetyToken: safetyToken,
          confirm: true,
          archive: Uint8List.fromList([1, 2, 3]),
        );
        expect(invalid.status, 400);
        expect(
          (await BoxRepository(database).getAllBoxes()).single.name,
          'Original',
        );

        final restored = await _call(
          client,
          server,
          'POST',
          '/api/v1/admin/backups/restore',
          cookie: adminCookie,
          csrf: csrf,
          safetyToken: safetyToken,
          confirm: true,
          archive: importFile.bytes,
        );
        expect(restored.status, 200, reason: restored.json.toString());
        expect(restored.json['restored'], true);
        expect(
          (await BoxRepository(database).getAllBoxes()).single.name,
          'Imported',
        );
        final restoredPictures = await PictureGalleryRepository(database)
            .getBoxPictures(importedId);
        expect(restoredPictures, hasLength(1));
        expect(restoredPictures.single.media.data, [4, 5, 6]);
        expect(restoredPictures.single.isPrimary, true);
        final otherConnection = await openServerDatabase(collectionFile);
        try {
          final persistedPictures = await PictureGalleryRepository(
            otherConnection,
          ).getBoxPictures(importedId);
          expect(persistedPictures.single.media.data, [4, 5, 6]);
        } finally {
          await otherConnection.close();
        }
        expect(accounts.hasAccounts, true);
        expect(
          (await _call(
            client,
            server,
            'GET',
            '/api/v1/boxes',
            cookie: keeperCookie,
          )).status,
          200,
        );
        expect(
          (await _call(
            client,
            server,
            'POST',
            '/api/v1/admin/backups/restore',
            cookie: adminCookie,
            csrf: csrf,
            safetyToken: safetyToken,
            confirm: true,
            archive: importFile.bytes,
          )).status,
          409,
        );

        final nextSafety = await _call(
          client,
          server,
          'GET',
          '/api/v1/admin/backups',
          cookie: adminCookie,
        );
        final changed = await _call(
          client,
          server,
          'POST',
          '/api/v1/boxes',
          cookie: keeperCookie,
          csrf: keeperLogin.json['csrfToken'] as String,
          json: {'name': 'Added after safety backup'},
        );
        expect(changed.status, 201);
        final stale = await _call(
          client,
          server,
          'POST',
          '/api/v1/admin/backups/restore',
          cookie: adminCookie,
          csrf: csrf,
          safetyToken: nextSafety.headers.value('X-Safety-Token'),
          confirm: true,
          archive: importFile.bytes,
        );
        expect(stale.status, 409);
        expect(stale.json['error']['code'], 'safety_backup_stale');
        expect(await BoxRepository(database).getAllBoxes(), hasLength(2));
      } finally {
        client.close(force: true);
        await server?.close(force: true);
        await source?.close();
        await database.close();
        accounts.close();
        await directory.delete(recursive: true);
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      }
    },
  );
}
