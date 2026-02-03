import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/services/gateway/preview_cache_manager.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late PreviewCacheManager cacheManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('preview_cache_test_');
    cacheManager = PreviewCacheManager(
      cachePath: tempDir.path,
      maxMemoryEntries: 10,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PreviewCacheManager', () {
    test('returns null for uncached preview', () async {
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
      final result = await cacheManager.getPreview(cid, 'image/png');
      expect(result, isNull);
    });

    test('caches and retrieves preview', () async {
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);

      await cacheManager.cachePreview(cid, 'image/png', data);
      final result = await cacheManager.getPreview(cid, 'image/png');

      expect(result, equals(data));
    });

    test('returns correct cache stats', () {
      final stats = cacheManager.getCacheStats();

      expect(stats['hits'], isNotNull);
      expect(stats['misses'], isNotNull);
      expect(stats['entries'], isNotNull);
      expect(stats['hitRate'], isNotNull);
    });

    test('memory cache is used for repeated requests', () async {
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
      final data = Uint8List.fromList([10, 20, 30]);

      await cacheManager.cachePreview(cid, 'text/plain', data);

      // First retrieval populates memory cache
      var result = await cacheManager.getPreview(cid, 'text/plain');
      expect(result, equals(data));

      // Second retrieval should come from memory cache
      result = await cacheManager.getPreview(cid, 'text/plain');
      expect(result, equals(data));
    });
  });
}

