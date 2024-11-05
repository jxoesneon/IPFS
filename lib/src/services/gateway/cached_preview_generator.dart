import 'dart:typed_data';
import '../../core/data_structures/block.dart';

class CachedPreviewGenerator {
  final PreviewCacheManager _cacheManager;
  final FilePreviewHandler _previewHandler;

  CachedPreviewGenerator(this._cacheManager, this._previewHandler);

  Future<Uint8List?> generatePreview(Block block, String contentType) async {
    // Try to get from cache first
    final cached = await _cacheManager.getPreview(block.cid, contentType);
    if (cached != null) {
      return cached;
    }

    // Generate new preview if not in cache
    final preview = _previewHandler.generatePreview(block, contentType);
    if (preview != null) {
      await _cacheManager.cachePreview(block.cid, contentType, preview);
    }

    return preview;
  }

  Future<void> preloadPreviews(List<Block> blocks) async {
    for (final block in blocks) {
      final contentType = _detectContentType(block);
      if (_previewHandler.isSupportedType(contentType)) {
        await generatePreview(block, contentType);
      }
    }
  }
}
