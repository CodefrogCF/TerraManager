import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_client/media/application/shared_overview_image_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'deduplicates concurrent loads and reuses results until refreshed',
    () async {
      var requests = 0;
      final cache = SharedOverviewImageCache(
        loadBytes: (_) async {
          requests++;
          return Uint8List(4);
        },
      );
      addTearDown(cache.dispose);
      final first = cache.image(1);
      expect(cache.image(1), same(first));
      final image = await first;
      expect(await cache.image(1), same(image));
      expect(requests, 1);
      expect(
        image,
        isA<ResizeImage>().having(
          (i) => i.policy,
          'resize policy',
          ResizeImagePolicy.fit,
        ),
      );
      cache.clear();
      expect(await cache.image(1), isNotNull);
      expect(requests, 2);
    },
  );

  test('least recently used entries are evicted at the entry limit', () async {
    final requests = <int>[];
    final cache = SharedOverviewImageCache(
      maxEntries: 2,
      loadBytes: (id) async {
        requests.add(id);
        return Uint8List(4);
      },
    );
    addTearDown(cache.dispose);
    await cache.image(1);
    await cache.image(2);
    await cache.image(1);
    await cache.image(3);
    await cache.image(1);
    await cache.image(2);
    expect(requests, [1, 2, 3, 2]);
  });

  test(
    'retained picture bytes are bounded independently of entry count',
    () async {
      final requests = <int>[];
      final cache = SharedOverviewImageCache(
        maxBytes: 6,
        loadBytes: (id) async {
          requests.add(id);
          return Uint8List(4);
        },
      );
      addTearDown(cache.dispose);
      await cache.image(1);
      await cache.image(2);
      await cache.image(1);
      expect(requests, [1, 2, 1]);
    },
  );

  test(
    'unrelated record updates retain pictures and changed media are discarded',
    () async {
      final requests = <int>[];
      final cache = SharedOverviewImageCache(
        loadBytes: (id) async {
          requests.add(id);
          return Uint8List(4);
        },
      );
      addTearDown(cache.dispose);
      await cache.image(1);
      await cache.image(2);
      cache.retain([1, 2]);
      await cache.image(1);
      cache.retain([2, 3]);
      await cache.image(2);
      await cache.image(3);
      await cache.image(1);
      expect(requests, [1, 2, 3, 1]);
    },
  );

  test(
    'failed images remain placeholders without a polling retry loop',
    () async {
      var requests = 0;
      final cache = SharedOverviewImageCache(
        loadBytes: (_) async {
          requests++;
          throw StateError('missing image');
        },
      );
      addTearDown(cache.dispose);
      expect(await cache.image(1), isNull);
      expect(await cache.image(1), isNull);
      expect(requests, 1);
      cache.clear();
      expect(await cache.image(1), isNull);
      expect(requests, 2);
    },
  );

  test(
    'limits simultaneous loads and never revives disposed session pictures',
    () async {
      final started = <int>[];
      final pending = <int, Completer<Uint8List>>{};
      final cache = SharedOverviewImageCache(
        maxConcurrentLoads: 2,
        loadBytes: (id) {
          started.add(id);
          return (pending[id] = Completer<Uint8List>()).future;
        },
      );
      final first = cache.image(1);
      final second = cache.image(2);
      final third = cache.image(3);
      expect(started, [1, 2]);
      pending[1]!.complete(Uint8List(4));
      await first;
      expect(started, [1, 2, 3]);
      final fourth = cache.image(4);
      cache.dispose();
      expect(await second, isNull);
      expect(await third, isNull);
      expect(await fourth, isNull);
      pending[2]!.complete(Uint8List(4));
      pending[3]!.complete(Uint8List(4));
      expect(await cache.image(1), isNull);
      expect(started, [1, 2, 3]);
    },
  );

  test(
    'late results cannot populate a new snapshot with the same media ID',
    () async {
      final pending = <Completer<Uint8List>>[];
      final cache = SharedOverviewImageCache(
        loadBytes: (_) {
          final request = Completer<Uint8List>();
          pending.add(request);
          return request.future;
        },
      );
      addTearDown(cache.dispose);
      final old = cache.image(1);
      cache.clear();
      final current = cache.image(1);
      pending.first.complete(Uint8List(4));
      expect(await old, isNull);
      pending.last.complete(Uint8List(5));
      expect(await current, isNotNull);
      expect(cache.image(1), same(current));
    },
  );
}
