import 'dart:io';

Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:8080/api/v1/health'),
    );
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
    exitCode = response.statusCode == HttpStatus.ok ? 0 : 1;
  } catch (_) {
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
