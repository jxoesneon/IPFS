// lib/src/services/gateway/compressed_cache_store.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_lz4/dart_lz4.dart';

import '../../utils/logger.dart';
import 'adaptive_compression_handler.dart';

/// Manages compressed cache storage with multiple compression algorithms.
class CompressedCacheStore {
  /// Creates a compressed cache store at [cachePath].
  CompressedCacheStore({required String cachePath, CompressionConfig? compressionConfig})
    : _cacheDir = Directory(cachePath),
      _compressionHandler = AdaptiveCompressionHandler(
        BlockStore(path: cachePath),
        compressionConfig ?? CompressionConfig(),
      ) {
    _initializeStore();
  }

  final Directory _cacheDir;
  final AdaptiveCompressionHandler _compressionHandler;
  final _logger = Logger('CompressedCacheStore');

  void _initializeStore() {
    if (!_cacheDir.existsSync()) {
      _cacheDir.createSync(recursive: true);
    }
  }

  /// Gets compressed data for a CID, decompressing before returning.
  Future<Uint8List?> getCompressedData(CID cid, String contentType) async {
    final cacheFile = File('${_cacheDir.path}/${_getCacheFileName(cid, contentType)}');

    if (!await cacheFile.exists()) return null;

    try {
      final compressedData = await cacheFile.readAsBytes();
      final metadata = await _readMetadata(cacheFile.path);
      final compressionType = _parseCompressionType(metadata['compression'] ?? 'gzip');

      return _decompress(compressedData, compressionType);
    } catch (e, stackTrace) {
      _logger.error('Error reading compressed cache', e, stackTrace);
      return null;
    }
  }

  /// Stores data with optimal compression for the content type.
  Future<void> storeCompressedData(CID cid, String contentType, Uint8List data) async {
    final compressionType = _compressionHandler.getOptimalCompression(contentType, data.length);

    if (compressionType == CompressionType.none) {
      await _storeUncompressed(cid, contentType, data);
      return;
    }

    final compressedData = _compress(data, compressionType);
    final analysis = _compressionHandler.analyzeCompression(data, contentType, {
      compressionType: compressedData.length,
    });

    await _storeWithMetadata(cid, contentType, compressedData, {
      'compression': compressionType.name,
      'originalSize': data.length.toString(),
      'compressedSize': compressedData.length.toString(),
      'compressionRatio': analysis.compressionRatios[compressionType].toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Uint8List _compress(Uint8List data, CompressionType type) {
    try {
      switch (type) {
        case CompressionType.none:
          return data;
        case CompressionType.gzip:
          final encoded = const GZipEncoder().encode(data);
          return Uint8List.fromList(encoded);
        case CompressionType.zlib:
          return Uint8List.fromList(const ZLibEncoder().encode(data));
        case CompressionType.lz4:
          return lz4FrameEncode(data);
      }
    } catch (e) {
      if (type == CompressionType.lz4) {
        // lz4FrameEncode throws if validation fails, catch below handles it
      }
      rethrow;
    }
  }

  Uint8List _decompress(Uint8List data, CompressionType type) {
    try {
      switch (type) {
        case CompressionType.none:
          return data;
        case CompressionType.gzip:
          return Uint8List.fromList(const GZipDecoder().decodeBytes(data));
        case CompressionType.zlib:
          return Uint8List.fromList(const ZLibDecoder().decodeBytes(data));

        case CompressionType.lz4:
          return lz4FrameDecode(data);
      }
    } catch (e) {
      // If decompression fails (especially LZ4), we can't really fallback
      // because the data IS compressed with that algorithm.
      // But we should catch the FFI error to prevent a hard crash.
      // But we should catch the FFI error to prevent a hard crash.
      _logger.error('Decompression failed for type: ${type.name}', e);
      throw FormatException('Failed to decompress data: ${e.toString()}');
    }
  }

  /// Returns compression statistics for the cache.
  CompressionStats getCompressionStats(String cachePath) {
    final stats = CompressionStats();
    final dir = Directory(cachePath);

    for (var file in dir.listSync(recursive: true)) {
      if (file is File && file.path.endsWith('.cache')) {
        final metadata = _readMetadataSync(file.path);
        final originalSize = int.parse(metadata['originalSize'] ?? '0');
        final compressedSize = int.parse(metadata['compressedSize'] ?? '0');

        stats.addEntry(originalSize, compressedSize);
      }
    }

    return stats;
  }

  String _getCacheFileName(CID cid, String contentType) {
    final hash = sha256.convert(utf8.encode('${cid.encode()}_$contentType')).toString();
    return '$hash.cache';
  }

  Future<Map<String, String>> _readMetadata(String filePath) async {
    final metadataFile = File('$filePath.meta');
    if (!await metadataFile.exists()) {
      return {};
    }

    try {
      final content = await metadataFile.readAsString();
      return Map<String, String>.from(json.decode(content) as Map<dynamic, dynamic>);
    } catch (e, stackTrace) {
      _logger.error('Error reading metadata file', e, stackTrace);
      return {};
    }
  }

  Map<String, String> _readMetadataSync(String filePath) {
    final metadataFile = File('$filePath.meta');
    if (!metadataFile.existsSync()) {
      return {};
    }

    try {
      final content = metadataFile.readAsStringSync();
      return Map<String, String>.from(json.decode(content) as Map<dynamic, dynamic>);
    } catch (e, stackTrace) {
      _logger.error('Error reading metadata file', e, stackTrace);
      return {};
    }
  }

  Future<void> _storeWithMetadata(
    CID cid,
    String contentType,
    Uint8List data,
    Map<String, String> metadata,
  ) async {
    final cacheFile = File('${_cacheDir.path}/${_getCacheFileName(cid, contentType)}');
    await cacheFile.writeAsBytes(data);

    final metadataFile = File('${cacheFile.path}.meta');
    await metadataFile.writeAsString(json.encode(metadata));
  }

  CompressionType _parseCompressionType(String name) {
    return CompressionType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => CompressionType.gzip,
    );
  }

  Future<void> _storeUncompressed(CID cid, String contentType, Uint8List data) async {
    await _storeWithMetadata(cid, contentType, data, {
      'compression': CompressionType.none.name,
      'originalSize': data.length.toString(),
      'compressedSize': data.length.toString(),
      'compressionRatio': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

/// Compression algorithm types.
enum CompressionType {
  /// No compression.
  none,

  /// GZIP compression.
  gzip,

  /// ZLIB compression.
  zlib,

  /// LZ4 compression.
  lz4,
}

/// Tracks compression statistics across multiple entries.
class CompressionStats {
  /// Total original (uncompressed) size in bytes.
  int totalOriginalSize = 0;

  /// Total compressed size in bytes.
  int totalCompressedSize = 0;

  /// Number of entries tracked.
  int fileCount = 0;

  /// Adds an entry to the statistics.
  void addEntry(int originalSize, int compressedSize) {
    totalOriginalSize += originalSize;
    totalCompressedSize += compressedSize;
    fileCount++;
  }

  /// Returns the overall compression ratio.
  double get compressionRatio =>
      totalOriginalSize == 0 ? 0 : totalCompressedSize / totalOriginalSize;
}
