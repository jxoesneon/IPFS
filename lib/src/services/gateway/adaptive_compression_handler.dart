// src/services/gateway/adaptive_compression_handler.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/services/gateway/compressed_cache_store.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:es_compression/lz4.dart' as es;

/// Configuration for adaptive compression.
class CompressionConfig {
  /// Creates compression configuration.
  CompressionConfig({
    this.enabled = true,
    this.maxUncompressedSize = 52428800, // 50MB
    Map<String, CompressionType>? contentTypeRules,
  }) : contentTypeRules = contentTypeRules ?? _defaultCompressionRules;

  /// Whether compression is enabled.
  final bool enabled;

  /// Maximum size for uncompressed content.
  final int maxUncompressedSize;

  /// Compression type rules by content type prefix.
  final Map<String, CompressionType> contentTypeRules;

  static final _defaultCompressionRules = {
    'text/': CompressionType.gzip,
    'application/json': CompressionType.gzip,
    'application/javascript': CompressionType.gzip,
    'image/': CompressionType.none,
    'video/': CompressionType.none,
    'audio/': CompressionType.none,
  };
}

/// Analysis results for compression options.
class CompressionAnalysis {
  /// Creates compression analysis results.
  CompressionAnalysis({
    required this.compressionRatios,
    required this.recommendedType,
  });

  /// Compression ratios by type.
  final Map<CompressionType, double> compressionRatios;

  /// The recommended compression type.
  final CompressionType recommendedType;
}

/// Handles adaptive compression for gateway content.
///
/// Selects optimal compression based on content type and size.
class AdaptiveCompressionHandler {
  /// Creates a handler with [_blockStore] and [_config].
  AdaptiveCompressionHandler(this._blockStore, this._config)
    : _metadataPath = '${_blockStore.path}/metadata';
  final BlockStore _blockStore;
  final CompressionConfig _config;
  final String _metadataPath;

  static bool? _lz4Available;
  final _logger = Logger('AdaptiveCompressionHandler');

  bool get _isLz4Available {
    if (_lz4Available != null) return _lz4Available!;
    try {
      // Try to instantiate AND use to trigger FFI load
      es.Lz4Encoder().convert([]);
      _lz4Available = true;
    } catch (e) {
      _logger.warning(
        'LZ4 compression unavailable (native binary missing). Falling back to GZIP.',
      );
      _lz4Available = false;
    }
    return _lz4Available!;
  }

  /// Compresses a block based on its content type.
  Future<Block> compressBlock(Block block, String contentType) async {
    if (!_config.enabled || block.size > _config.maxUncompressedSize) {
      return block;
    }

    final compressionType = getOptimalCompression(contentType, block.size);
    if (compressionType == CompressionType.none) {
      return block;
    }

    final compressedData = await _compressData(block.data, compressionType);
    if (compressedData.length >= block.size) {
      return block; // Skip if compression doesn't help
    }

    // Create new block with compressed data and store it in the blockstore
    final compressedBlock = await Block.fromData(compressedData, format: 'raw');

    // Store the compressed block
    await _blockStore.putBlock(compressedBlock);

    // Store compression metadata
    await _storeCompressionMetadata(block.cid, {
      'originalSize': block.size.toString(),
      'compressedSize': compressedData.length.toString(),
      'compressionType': compressionType.name,
      'originalCid': block.cid.encode(),
    });

    return compressedBlock;
  }

  /// Determines optimal compression for content type and size.
  CompressionType getOptimalCompression(String contentType, int size) {
    for (final entry in _config.contentTypeRules.entries) {
      if (contentType.startsWith(entry.key)) {
        final type = entry.value;
        // Fallback checks
        if (type == CompressionType.lz4 && !_isLz4Available) {
          return CompressionType.gzip;
        }
        return type;
      }
    }
    return CompressionType.gzip;
  }

  Future<Uint8List> _compressData(Uint8List data, CompressionType type) async {
    switch (type) {
      case CompressionType.none:
        return data;
      case CompressionType.gzip:
        return Uint8List.fromList(gzip.encode(data));
      case CompressionType.zlib:
        return Uint8List.fromList(zlib.encode(data));

      case CompressionType.lz4:
        return Uint8List.fromList(es.Lz4Encoder().convert(data));
    }
  }

  Future<void> _storeCompressionMetadata(
    CID cid,
    Map<String, String> metadata,
  ) async {
    final metadataFile = File('$_metadataPath/${cid.encode()}.json');
    await metadataFile.parent.create(recursive: true);
    await metadataFile.writeAsString(jsonEncode(metadata));
  }

  /// Analyzes compression efficiency across algorithms.
  CompressionAnalysis analyzeCompression(
    Uint8List data,
    String contentType,
    Map<CompressionType, int> compressedSizes,
  ) {
    final ratios = <CompressionType, double>{};

    for (final entry in compressedSizes.entries) {
      ratios[entry.key] = entry.value / data.length;
    }

    // Find the compression type with the best ratio
    var bestType = CompressionType.none;
    var bestRatio = 1.0;

    for (final entry in ratios.entries) {
      if (entry.value < bestRatio) {
        bestRatio = entry.value;
        bestType = entry.key;
      }
    }

    return CompressionAnalysis(
      compressionRatios: ratios,
      recommendedType: bestType,
    );
  }
}
