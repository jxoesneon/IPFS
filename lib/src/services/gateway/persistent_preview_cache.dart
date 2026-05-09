// lib/src/services/gateway/persistent_preview_cache.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:path/path.dart' as path;

/// A persistent cache for preview data using the platform's storage.
class PersistentPreviewCache {
  /// Creates a [PersistentPreviewCache] at the given [cachePath].
  PersistentPreviewCache({
    required this.cachePath,
    int maxCacheSize = 1024 * 1024 * 1024, // 1GB default
  }) : _maxCacheSize = maxCacheSize {
    _initializeCache();
  }

  /// The directory where preview data is stored.
  final String cachePath;
  final int _maxCacheSize;
  int _currentCacheSize = 0;

  Future<void> _initializeCache() async {
    if (!await getPlatform().exists(cachePath)) {
      await getPlatform().createDirectory(cachePath);
    }
    await _calculateCurrentCacheSize();
  }

  Future<void> _calculateCurrentCacheSize() async {
    _currentCacheSize = 0;
    final files = await getPlatform().listDirectory(cachePath);
    for (final filePath in files) {
      if (filePath.endsWith('.cache')) {
        _currentCacheSize += await getPlatform().getLength(filePath);
      }
    }
  }

  /// Retrieves a cached preview for the given CID and content type.
  Future<Uint8List?> getPreview(CID cid, String contentType) async {
    final cacheFilePath = path.join(
      cachePath,
      _getCacheFileName(cid, contentType),
    );

    if (await getPlatform().exists(cacheFilePath)) {
      try {
        return await getPlatform().readBytes(cacheFilePath);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Caches a preview for the given CID and content type.
  Future<void> cachePreview(
    CID cid,
    String contentType,
    Uint8List preview,
  ) async {
    if (preview.length > _maxCacheSize) return;

    final cacheFilePath = path.join(
      cachePath,
      _getCacheFileName(cid, contentType),
    );

    // Check if we need to free up space
    if (_currentCacheSize + preview.length > _maxCacheSize) {
      await _evictOldEntries(preview.length);
    }

    try {
      await getPlatform().writeBytes(cacheFilePath, preview);
      _currentCacheSize += preview.length;

      // Write metadata
      await _writeCacheMetadata(cacheFilePath, {
        'cid': cid.encode(),
        'contentType': contentType,
        'size': preview.length.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _evictOldEntries(int requiredSpace) async {
    // Basic eviction: delete all and recalculate for now
    // In a real app, we should use last modified time
    final files = await getPlatform().listDirectory(cachePath);
    for (final filePath in files) {
      if (filePath.endsWith('.cache')) {
        await getPlatform().delete(filePath);
        await _deleteCacheMetadata(filePath);
      }
    }
    _currentCacheSize = 0;
  }

  String _getCacheFileName(CID cid, String contentType) {
    final hash = sha256
        .convert(utf8.encode('${cid.encode()}_$contentType'))
        .toString();
    return '$hash.cache';
  }

  Future<void> _writeCacheMetadata(
    String cacheFilePath,
    Map<String, String> metadata,
  ) async {
    final metadataPath = '$cacheFilePath.meta';
    await getPlatform().writeBytes(
      metadataPath,
      Uint8List.fromList(utf8.encode(json.encode(metadata))),
    );
  }

  Future<void> _deleteCacheMetadata(String cacheFilePath) async {
    final metadataPath = '$cacheFilePath.meta';
    if (await getPlatform().exists(metadataPath)) {
      await getPlatform().delete(metadataPath);
    }
  }
}
