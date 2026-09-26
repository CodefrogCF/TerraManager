import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// In-memory pictures for one mounted overview, never a persistent collection.
/// Failed loads remain placeholders until the next overview snapshot.
class SharedOverviewImageCache {
  SharedOverviewImageCache({
    required this.loadBytes,
    this.maxEntries = 128,
    this.maxBytes = 32 * 1024 * 1024,
    this.maxConcurrentLoads = 4,
  }) : assert(maxEntries > 0),
       assert(maxBytes > 0),
       assert(maxConcurrentLoads > 0);

  final Future<Uint8List> Function(int mediaId) loadBytes;
  final int maxEntries;
  final int maxBytes;
  final int maxConcurrentLoads;
  final _entries = <int, _ImageEntry>{};
  final _pending = Queue<_ImageEntry>();
  int _bytes = 0;
  int _active = 0;
  bool _disposed = false;

  Future<ImageProvider?> image(int mediaId) {
    if (_disposed) return Future.value(null);
    final entry = _entries.remove(mediaId) ?? _ImageEntry(mediaId);
    _entries[mediaId] = entry;
    if (!entry.requested) {
      entry.requested = true;
      _pending.add(entry);
    }
    _trim();
    _drain();
    return entry.result.future;
  }

  /// Media IDs are immutable; record revisions and Feeding changes need no reload.
  void retain(Iterable<int> mediaIds) {
    final ids = mediaIds.toSet();
    for (final entry in _entries.values.toList()) {
      if (!ids.contains(entry.mediaId)) _remove(entry);
    }
  }

  void clear() {
    for (final entry in _entries.values.toList()) {
      _remove(entry);
    }
  }

  void dispose() {
    _disposed = true;
    clear();
  }

  void _remove(_ImageEntry entry) {
    _entries.remove(entry.mediaId);
    _pending.remove(entry);
    _bytes -= entry.bytes;
    final provider = entry.provider;
    if (provider != null) unawaited(provider.evict());
    if (!entry.result.isCompleted) entry.result.complete(null);
  }

  void _trim() {
    while (_entries.length > maxEntries || _bytes > maxBytes) {
      _remove(_entries.values.first);
    }
  }

  void _drain() {
    while (!_disposed && _active < maxConcurrentLoads && _pending.isNotEmpty) {
      final entry = _pending.removeFirst();
      _active++;
      unawaited(_load(entry));
    }
  }

  Future<void> _load(_ImageEntry entry) async {
    try {
      final bytes = await loadBytes(entry.mediaId);
      // A previous snapshot or session must not repopulate a cleared cache.
      if (_disposed || !identical(_entries[entry.mediaId], entry)) return;
      entry.provider = ResizeImage(
        MemoryImage(bytes),
        width: 512,
        height: 512,
        policy: ResizeImagePolicy.fit,
      );
      entry.bytes = bytes.length;
      _bytes += entry.bytes;
      _trim();
      if (!entry.result.isCompleted) entry.result.complete(entry.provider);
    } catch (_) {
      if (!entry.result.isCompleted) entry.result.complete(null);
    } finally {
      _active--;
      _drain();
    }
  }
}

class _ImageEntry {
  _ImageEntry(this.mediaId);
  final int mediaId;
  final result = Completer<ImageProvider?>();
  bool requested = false;
  ImageProvider? provider;
  int bytes = 0;
}
