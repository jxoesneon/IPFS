// lib/src/services/gateway/compressed_cache_store.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' hide CompressionType;
import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_lz4/dart_lz4.dart';

import '../../utils/logger.dart';
import 'adaptive_compression_handler.dart';

/// Manages compressed cache storage with multiple compression algorithms.
class CompressedCacheStore {
  /// Creates a compressed cache store at [cachePath].
  CompressedCacheStore({
    required this.cachePath,
    CompressionConfig? compressionConfig,
  }) : _compressionHandler = AdaptiveCompressionHandler(
         BlockStore(path: cachePath),
         compressionConfig ?? CompressionConfig(),
       ) {
    _initializeStore();
  }

  /// The path to the cache directory.
  final String cachePath;
  final AdaptiveCompressionHandler _compressionHandler;
  final _logger = Logger('CompressedCacheStore');

  Future<void> _initializeStore() async {
    if (!await getPlatform().exists(cachePath)) {
      await getPlatform().createDirectory(cachePath);
    }
  }

  /// Gets compressed data for a CID, decompressing before returning.
  Future<Uint8List?> getCompressedData(CID cid, String contentType) async {
    final cacheFilePath = '$cachePath/${_getCacheFileName(cid, contentType)}';

    if (!await getPlatform().exists(cacheFilePath)) return null;

    try {
      final compressedData = await getPlatform().readBytes(cacheFilePath);
      if (compressedData == null) return null;

      final metadata = await _readMetadata(cacheFilePath);
      final compressionType = _parseCompressionType(
        metadata['compression'] ?? 'gzip',
      );

      return _decompress(compressedData, compressionType);
    } catch (e, stackTrace) {
      _logger.error('Error reading compressed cache', e, stackTrace);
      return null;
    }
  }

  /// Stores data with optimal compression for the content type.
  Future<void> storeCompressedData(
    CID cid,
    String contentType,
    Uint8List data,
  ) async {
    final compressionType = _compressionHandler.getOptimalCompression(
      contentType,
      data.length,
    );

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
      'compressionRatio': (analysis.compressionRatios[compressionType] ?? 1.0)
          .toString(),
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
          final encoded = const ZLibEncoder().encode(data);
          return Uint8List.fromList(encoded);
        case CompressionType.lz4:
          return lz4FrameEncode(data);
      }
    } catch (e) {
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
      _logger.error('Decompression failed for type: ${type.name}', e);
      throw FormatException('Failed to decompress data: ${e.toString()}');
    }
  }

  /// Returns compression statistics for the cache.
  Future<CompressionStats> getCompressionStats(String cachePath) async {
    final stats = CompressionStats();
    final files = await getPlatform().listDirectory(cachePath);

    for (var filePath in files) {
      if (filePath.endsWith('.cache')) {
        final metadata = await _readMetadata(filePath);
        final originalSize = int.parse(metadata['originalSize'] ?? '0');
        final compressedSize = int.parse(metadata['compressedSize'] ?? '0');

        stats.addEntry(originalSize, compressedSize);
      }
    }

    return stats;
  }

  String _getCacheFileName(CID cid, String contentType) {
    final hash = sha256
        .convert(utf8.encode('${cid.encode()}_$contentType'))
        .toString();
    return '$hash.cache';
  }

  Future<Map<String, String>> _readMetadata(String filePath) async {
    final metadataPath = '$filePath.meta';
    if (!await getPlatform().exists(metadataPath)) {
      return {};
    }

    try {
      final content = await getPlatform().readString(metadataPath);
      if (content == null) return {};
      return Map<String, String>.from(
        json.decode(content) as Map<dynamic, dynamic>,
      );
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
    final cacheFilePath = '$cachePath/${_getCacheFileName(cid, contentType)}';
    await getPlatform().writeBytes(cacheFilePath, data);

    final metadataPath = '$cacheFilePath.meta';
    await getPlatform().writeBytes(
      metadataPath,
      Uint8List.fromList(utf8.encode(json.encode(metadata))),
    );
  }

  CompressionType _parseCompressionType(String name) {
    return CompressionType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => CompressionType.gzip,
    );
  }

  Future<void> _storeUncompressed(
    CID cid,
    String contentType,
    Uint8List data,
  ) async {
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
