import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_server/changes/application/coalescing_stream_writer.dart';

void main() {
  test('ten thousand hints retain only one pending write', () async {
    final first = Completer<void>();
    var writes = 0;
    final writer = CoalescingStreamWriter(
      write: () async {
        writes++;
        if (writes == 1) await first.future;
      },
      onFailure: () => fail('Unexpected failure'),
      timeout: const Duration(seconds: 1),
    );
    writer.request();
    for (var i = 0; i < 10000; i++) {
      writer.request();
    }
    expect(writes, 1);
    first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(writes, 2);
    writer.close();
  });
  test(
    'a stalled consumer times out once and accepts no more writes',
    () async {
      var writes = 0, failures = 0;
      final writer = CoalescingStreamWriter(
        write: () {
          writes++;
          return Completer<void>().future;
        },
        onFailure: () => failures++,
        timeout: const Duration(milliseconds: 20),
      );
      writer.request();
      writer.request();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(writer.closed, true);
      expect(writes, 1);
      expect(failures, 1);
      writer.request();
      expect(writes, 1);
    },
  );
  test('disconnect cancels a pending deadline and queued work', () async {
    var writes = 0, failures = 0;
    final writer = CoalescingStreamWriter(
      write: () {
        writes++;
        return Completer<void>().future;
      },
      onFailure: () => failures++,
      timeout: const Duration(milliseconds: 20),
    );
    writer.request();
    writer.request();
    writer.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(writes, 1);
    expect(failures, 0);
  });
}
