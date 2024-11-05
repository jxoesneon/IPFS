import 'dart:typed_data';
import 'package:mime/mime.dart';
import '../../core/config/config.dart';
import '../../core/data_structures/block.dart';
import '../../core/data_structures/blockstore.dart';

class CompressionConfig {
  final bool enabled;
  final int maxUncompressedSize;
  final Map<String, CompressionType> contentTypeRules;
  
  CompressionConfig({
    this.enabled = true,
    this.maxUncompressedSize = 52428800, // 50MB
    Map<String, CompressionType>? contentTypeRules,
  }) : contentTypeRules = contentTypeRules ?? defaultCompressionRules;

  static const defaultCompressionRules = {
    'text/': CompressionType.gzip,
    'application/json': CompressionType.gzip,
    'application/javascript': CompressionType.gzip,
    'image/': CompressionType.none,
    'video/': CompressionType.none,
    'audio/': CompressionType.none,
  };
}

class AdaptiveCompressionHandler {
  final BlockStore _blockStore;
  final CompressionConfig _config;
  
  AdaptiveCompressionHandler(this._blockStore, this._config);

  Future<Block> compressBlock(Block block, String contentType) async {
    if (!_config.enabled || block.size() > _config.maxUncompressedSize) {
      return block;
    }

    final compressionType = _getOptimalCompression(contentType, block.size());
    if (compressionType == CompressionType.none) {
      return block;
    }

    final compressedData = await _compressData(block.data, compressionType);
    if (compressedData.length >= block.size()) {
      return block; // Skip if compression doesn't help
    }

    // Create new block with compressed data
    final compressedBlock = Block.fromData(
      compressedData,
      block.cid,
    );

    // Store compression metadata
    await _storeCompressionMetadata(block.cid, {
      'originalSize': block.size().toString(),
      'compressedSize': compressedData.length.toString(),
      'compressionType': compressionType.name,
    });

    return compressedBlock;
  }

  CompressionType _getOptimalCompression(String contentType, int size) {
    for (final entry in _config.contentTypeRules.entries) {
      if (contentType.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return CompressionType.lz4; // Default to fast compression
  }
} 