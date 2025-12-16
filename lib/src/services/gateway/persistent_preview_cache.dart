import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:path/path.dart' as path;

/// Manages persistent caching of file previews on disk
class PersistentPreviewCache {
  final Directory _cacheDir;
  final int _maxCacheSize;
  int _currentCacheSize = 0;

  PersistentPreviewCache({
    required String cachePath,
    int maxCacheSize = 1024 * 1024 * 1024, // 1GB default
  }) : _cacheDir = Directory(cachePath),
       _maxCacheSize = maxCacheSize {
    _initializeCache();
  }

  Future<void> _initializeCache() async {
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
    await _calculateCurrentCacheSize();
  }

  Future<void> _calculateCurrentCacheSize() async {
    _currentCacheSize = 0;
    await for (final file in _cacheDir.list(recursive: true)) {
      if (file is File) {
        _currentCacheSize += await file.length();
      }
    }
  }

  Future<Uint8List?> getPreview(CID cid, String contentType) async {
    final cacheFile = File(
      path.join(_cacheDir.path, _getCacheFileName(cid, contentType)),
    );

    if (await cacheFile.exists()) {
      try {
        return await cacheFile.readAsBytes();
      } catch (e) {
        // print('Error reading cached preview: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> cachePreview(
    CID cid,
    String contentType,
    Uint8List preview,
  ) async {
    if (preview.length > _maxCacheSize) return;

    final cacheFile = File(
      path.join(_cacheDir.path, _getCacheFileName(cid, contentType)),
    );

    // Check if we need to free up space
    if (_currentCacheSize + preview.length > _maxCacheSize) {
      await _evictOldEntries(preview.length);
    }

    try {
      await cacheFile.writeAsBytes(preview);
      _currentCacheSize += preview.length;

      // Write metadata
      await _writeCacheMetadata(cacheFile.path, {
        'cid': cid.encode(),
        'contentType': contentType,
        'size': preview.length.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // print('Error caching preview: $e');
    }
  }

  Future<void> _evictOldEntries(int requiredSpace) async {
    final entries = await _getCacheEntries();

    // Get last modified times for sorting
    final entriesWithTimes = await Future.wait(
      entries.map((entry) async {
        final stat = await entry.stat();
        return MapEntry(entry, stat.modified);
      }),
    );

    // Sort by modified time
    entriesWithTimes.sort((a, b) => a.value.compareTo(b.value));

    int freedSpace = 0;
    for (final entry in entriesWithTimes) {
      if (_currentCacheSize - freedSpace + requiredSpace <= _maxCacheSize) {
        break;
      }

      final file = File(entry.key.path);
      freedSpace += await file.length();
      await file.delete();
      await _deleteCacheMetadata(entry.key.path);
    }

    _currentCacheSize -= freedSpace;
  }

  String _getCacheFileName(CID cid, String contentType) {
    final hash = sha256
        .convert(utf8.encode('${cid.encode()}_$contentType'))
        .toString();
    return '$hash.cache';
  }

  Future<void> _writeCacheMetadata(
    String cachePath,
    Map<String, String> metadata,
  ) async {
    final metadataFile = File('$cachePath.meta');
    await metadataFile.writeAsString(json.encode(metadata));
  }

  Future<void> _deleteCacheMetadata(String cachePath) async {
    final metadataFile = File('$cachePath.meta');
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }
  }

  Future<List<FileSystemEntity>> _getCacheEntries() async {
    return await _cacheDir
        .list()
        .where((entity) => entity.path.endsWith('.cache'))
        .toList();
  }
}
