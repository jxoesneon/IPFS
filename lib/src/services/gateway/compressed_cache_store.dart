import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'adaptive_compression_handler.dart';
import '../../core/data_structures/cid.dart';

/// Manages compressed cache storage with multiple compression algorithms
class CompressedCacheStore {
  final Directory _cacheDir;
  final AdaptiveCompressionHandler _compressionHandler;
  
  CompressedCacheStore({
    required String cachePath,
  }) : _cacheDir = Directory(cachePath), _compressionHandler = AdaptiveCompressionHandler() {
    _initializeStore();
  }

  void _initializeStore() {
    if (!_cacheDir.existsSync()) {
      _cacheDir.createSync(recursive: true);
    }
  }

  Future<Uint8List?> getCompressedData(CID cid, String contentType) async {
    final cacheFile = File('${_cacheDir.path}/${_getCacheFileName(cid, contentType)}');
    
    if (!await cacheFile.exists()) return null;

    try {
      final compressedData = await cacheFile.readAsBytes();
      final metadata = await _readMetadata(cacheFile.path);
      final compressionType = _parseCompressionType(metadata['compression'] ?? 'gzip');
      
      return _decompress(compressedData, compressionType);
    } catch (e) {
      print('Error reading compressed cache: $e');
      return null;
    }
  }

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
    final analysis = _compressionHandler.analyzeCompression(
      data,
      contentType,
      {compressionType: compressedData.length},
    );

    await _storeWithMetadata(cid, contentType, compressedData, {
      'compression': compressionType.name,
      'originalSize': data.length.toString(),
      'compressedSize': compressedData.length.toString(),
      'compressionRatio': analysis.compressionRatios[compressionType].toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Uint8List _compress(Uint8List data, CompressionType type) {
    switch (type) {
      case CompressionType.gzip:
        return GZipEncoder().encode(data)!;
      case CompressionType.zlib:
        return ZLibEncoder().encode(data);
      case CompressionType.lz4:
        return LZ4Encoder().encode(data);
    }
  }

  Uint8List _decompress(Uint8List data, CompressionType type) {
    switch (type) {
      case CompressionType.gzip:
        return Uint8List.fromList(GZipDecoder().decodeBytes(data));
      case CompressionType.zlib:
        return ZLibDecoder().decodeBytes(data);
      case CompressionType.lz4:
        return LZ4Decoder().decodeBytes(data);
    }
  }

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
}

enum CompressionType {
  gzip,
  zlib,
  lz4,
}

class CompressionStats {
  int totalOriginalSize = 0;
  int totalCompressedSize = 0;
  int fileCount = 0;

  void addEntry(int originalSize, int compressedSize) {
    totalOriginalSize += originalSize;
    totalCompressedSize += compressedSize;
    fileCount++;
  }

  double get compressionRatio => 
    totalOriginalSize == 0 ? 0 : totalCompressedSize / totalOriginalSize;
} 