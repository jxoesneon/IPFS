import 'dart:convert';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';

/// Handles lazy loading of file previews in the directory listing
class LazyPreviewHandler {
  final Map<String, Block> _previewCache = {};

  /// Generates a lazy loading placeholder for a preview
  String generateLazyPreview(Block block, String contentType) {
    final previewId = _generatePreviewId(block.cid);
    _previewCache[previewId] = block;

    return '''
      <div class="preview-container lazy" 
           data-preview-id="$previewId"
           data-content-type="$contentType">
        <div class="preview-placeholder">
          <div class="preview-spinner"></div>
          <span>Loading preview...</span>
        </div>
      </div>
    ''';
  }

  /// Generates the JavaScript needed for lazy loading
  String generateLazyLoadScript() {
    return '''
      <script>
        const observerOptions = {
          root: null,
          rootMargin: '50px',
          threshold: 0.1
        };

        const loadPreview = async (element) => {
          const previewId = element.dataset.previewId;
          const contentType = element.dataset.contentType;
          
          try {
            const response = await fetch('/api/preview/' + previewId);
            const data = await response.json();
            
            if (data.preview) {
              element.innerHTML = data.preview;
              element.classList.remove('lazy');
            }
          } catch (error) {
            console.error('Error loading preview:', error);
            element.innerHTML = '<div class="preview-error">Preview failed to load</div>';
          }
        };

        const observer = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              loadPreview(entry.target);
              observer.unobserve(entry.target);
            }
          });
        }, observerOptions);

        document.querySelectorAll('.preview-container.lazy').forEach(element => {
          observer.observe(element);
        });
      </script>
    ''';
  }

  /// Generates CSS styles for lazy loading
  String generateLazyLoadStyles() {
    return '''
      .preview-container.lazy {
        min-height: 100px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .preview-placeholder {
        text-align: center;
        color: #666;
      }
      .preview-spinner {
        width: 30px;
        height: 30px;
        border: 3px solid #f3f3f3;
        border-top: 3px solid #3498db;
        border-radius: 50%;
        margin: 0 auto 10px;
        animation: spin 1s linear infinite;
      }
      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }
      .preview-error {
        color: #e74c3c;
        padding: 10px;
      }
    ''';
  }

  String _generatePreviewId(CID cid) {
    return base64Url.encode(cid.toBytes());
  }

  /// Retrieves a preview block from the cache using its preview ID.
  ///
  /// Returns:
  /// - The [Block] if found and valid
  /// - null if the block is not found, invalid, or an error occurs
  ///
  /// Throws:
  /// - [ArgumentError] if previewId is null or empty
  Block? getPreviewBlock(String previewId) {
    // Validate input
    if (previewId.isEmpty) {
      throw ArgumentError('Preview ID cannot be empty');
    }

    try {
      // Check if block exists in cache
      if (!_previewCache.containsKey(previewId)) {
        print('Preview block not found for ID: $previewId');
        return null;
      }

      final block = _previewCache[previewId];

      // Validate block integrity
      if (block == null || !_isValidBlock(block)) {
        print('Retrieved block is null or invalid for ID: $previewId');
        _previewCache.remove(previewId); // Remove invalid entry
        return null;
      }

      // Optional: Track cache hits/misses for monitoring
      _logCacheAccess(previewId, true);

      // Remove from cache after successful retrieval
      // Comment out this line if you want to keep blocks cached
      _previewCache.remove(previewId);

      return block;
    } catch (e, stackTrace) {
      print('Error retrieving preview block: $e');
      print('Stack trace: $stackTrace');
      _logError('getPreviewBlock', previewId, e, stackTrace);
      return null;
    }
  }

  /// Validates that a block has the required properties and data
  bool _isValidBlock(Block block) {
    try {
      // Check if block data exists and is not empty
      if (block.data.isEmpty) {
        return false;
      }

      // Verify block integrity by checking CID matches content
      final computedCid =
          CID.computeForDataSync(block.data, codec: block.format);
      if (computedCid != block.cid) {
        return false;
      }

      // Additional validation based on block format
      if (block.format == 'raw' && block.data.length > 1024 * 1024) {
        // 1MB limit for raw blocks
        return false;
      }

      return true;
    } catch (e) {
      print('Block validation error: $e');
      return false;
    }
  }

  /// Logs cache access for monitoring purposes
  void _logCacheAccess(String previewId, bool isHit) {
    final timestamp = DateTime.now().toIso8601String();
    print(
        'Cache ${isHit ? 'HIT' : 'MISS'} at $timestamp for preview ID: $previewId');
    print('Current cache size: ${_previewCache.length}');
  }

  /// Logs errors with detailed information for debugging
  void _logError(
      String operation, String previewId, Object error, StackTrace stackTrace) {
    final timestamp = DateTime.now().toIso8601String();
    print('''
Error in LazyPreviewHandler.$operation
Timestamp: $timestamp
Preview ID: $previewId
Error: $error
Stack trace:
$stackTrace
Current cache size: ${_previewCache.length}
''');
  }
}
