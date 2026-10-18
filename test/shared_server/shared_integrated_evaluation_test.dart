import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/evaluation/shared_updates/lab_server.dart';

void main() {
  test('integrated fixture uses production change queries and separate bounded client accounts', () async {
    final scratch = await Directory.systemTemp.createTemp('tm230-test-');
    final lab = await UpdateEvaluationLab.start(
      scratchParent: scratch,
      assets: Directory('tool/evaluation/shared_updates/web'),
      animalCount: 2,
      historyPerAnimal: 1,
      integrated: true,
    );
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await lab.close();
      await scratch.delete();
    });
    final credentials = jsonDecode(
      await File('${lab.directory.path}/credentials.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(credentials['kind'], 'disposable-integrated-shared-care');
    final accounts = credentials['clients'] as List;
    expect(accounts, hasLength(3));
    expect(accounts.map((e) => e['username']).toSet(), hasLength(3));
    final login = await client.postUrl(
      Uri.parse('http://127.0.0.1:${lab.server.port}/api/v1/auth/login'),
    );
    login.headers.set('Origin', 'http://localhost:${lab.server.port}');
    login.headers.contentType = ContentType.json;
    login.write(jsonEncode(accounts.first));
    final loggedIn = await login.close();
    expect(loggedIn.statusCode, 200);
    final cookie = loggedIn.headers.value('set-cookie')!.split(';').first;
    await loggedIn.drain<void>();
    Future<Map<String, dynamic>> read(String path, [int status = 200]) async {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${lab.server.port}$path'),
      );
      request.headers.set('Cookie', cookie);
      final response = await request.close();
      expect(response.statusCode, status);
      return jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>;
    }

    final identity = await read('/evaluation/state');
    expect(identity['kind'], credentials['kind']);
    expect(identity['fixtureId'], credentials['fixtureId']);
    expect(identity.containsKey('cursor'), isFalse);
    final changes = await read('/api/v1/changes');
    expect(changes['reset'], isTrue);
    expect(changes['cursor'], isA<String>());
    expect(changes.containsKey('events'), isFalse);
    await read('/evaluation/events', 404);
    await read('/evaluation/changes', 404);
    final metrics = await read('/evaluation/metrics');
    expect(metrics['streams'], 0);
    expect(metrics['maximumConnections'], 32);
    expect(metrics['maximumPerAccount'], 8);
    expect((await read('/api/v1/animals'))['animals'], hasLength(2));
  });
}
