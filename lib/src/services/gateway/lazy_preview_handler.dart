import 'dart:convert';
import 'dart:typed_data';
import '../../core/data_structures/cid.dart';
import '../../core/data_structures/block.dart';

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
} 