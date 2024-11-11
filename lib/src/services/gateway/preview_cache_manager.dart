import 'dart:typed_data';
import 'package:dart_ipfs/src/services/gateway/gateway_lru_cache.dart';

import 'compressed_cache_store.dart';
import 'package:dart_ipfs/src/core/cid.dart';

/// Manages caching of file previews with multiple strategies
class PreviewCacheManager {
  final CompressedCacheStore _compressedStore;
  final GatewayLruCache<String, Uint8List> _memoryCache;

  PreviewCacheManager({
    required String cachePath,
    int maxMemoryEntries = 100,
  })  : _compressedStore = CompressedCacheStore(
          cachePath: cachePath,
        ),
        _memoryCache = GatewayLruCache(maxMemoryEntries);

  Future<Uint8List?> getPreview(CID cid, String contentType) async {
    // Check memory cache first
    final memCached = _memoryCache.get(_generateCacheKey(cid, contentType));
    if (memCached != null) return memCached;

    // Try compressed cache
    final compressed =
        await _compressedStore.getCompressedData(cid, contentType);
    if (compressed != null) {
      _memoryCache.put(_generateCacheKey(cid, contentType), compressed);
      return compressed;
    }

    return null;
  }

  Future<void> cachePreview(
      CID cid, String contentType, Uint8List preview) async {
    _memoryCache.put(_generateCacheKey(cid, contentType), preview);
    await _compressedStore.storeCompressedData(cid, contentType, preview);
  }

  String _generateCacheKey(CID cid, String contentType) {
    return '${cid.encode()}_$contentType';
  }

  Map<String, int> getCacheStats() {
    return {
      'hits': _memoryCache.length,
      'misses': 0,
      'entries': _memoryCache.length,
      'hitRate': _memoryCache.length == 0
          ? 0
          : (_memoryCache.length / (_memoryCache.length + 0) * 100).round(),
    };
  }
}
