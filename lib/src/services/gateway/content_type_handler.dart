// lib/src/services/gateway/content_type_handler.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:mime/mime.dart';

import '../../core/data_structures/block.dart';
import 'directory_parser.dart';

/// Handles content type detection and processing for IPFS gateway responses
class ContentTypeHandler {
  static const _defaultType = 'application/octet-stream';
  static final _mimeResolver = MimeTypeResolver()
    ..addExtension('md', 'text/markdown')
    ..addExtension('ipfs', 'application/vnd.ipfs.car')
    ..addExtension('car', 'application/vnd.ipfs.car');

  final _directoryParser = DirectoryParser();
  final _logger = Logger('ContentTypeHandler');

  final Map<String, String> _contentTypeCache = {};

  /// Detects the content type of a block based on its data and metadata
  String detectContentType(Block block, {String? filename}) {
    // Check if it's a directory listing
    if (_isDirectoryListing(block)) {
      return 'text/html';
    }

    // Try to detect from filename if provided
    if (filename != null) {
      final mimeType = _mimeResolver.lookup(filename);
      if (mimeType != null) return mimeType;
    }

    // Try to detect from content
    final mimeType = _detectFromContent(block.data);
    if (mimeType != null) return mimeType;

    // Default to octet-stream if detection fails
    return _defaultType;
  }

  /// Processes the block data based on content type
  Uint8List processContent(Block block, String contentType) {
    switch (contentType) {
      case 'text/html':
        if (_isDirectoryListing(block)) {
          return _generateDirectoryListing(block);
        }
        return block.data;

      case 'text/markdown':
        return _processMarkdown(block.data);

      case 'application/vnd.ipfs.car':
        return _processCarArchive(block.data);

      default:
        return block.data;
    }
  }

  /// Checks if the block represents a directory listing
  bool _isDirectoryListing(Block block) {
    try {
      return block.cid.codec == 'dag-pb' &&
          block.data.isNotEmpty &&
          block.data[0] == 0x08; // Directory marker in dag-pb
    } catch (e) {
      return false;
    }
  }

  /// Generates an HTML directory listing
  Uint8List _generateDirectoryListing(Block block) {
    try {
      final directory = _directoryParser.parseDirectoryBlock(block);
      final path = _extractPathFromRequest() ?? '/';
      final html = _directoryParser.generateHtmlListing(directory, path);
      return Uint8List.fromList(html.codeUnits);
    } catch (e, stackTrace) {
      _logger.error('Error generating directory listing', e, stackTrace);
      return Uint8List.fromList(
        'Error: Failed to generate directory listing'.codeUnits,
      );
    }
  }

  /// Processes markdown content by converting it to HTML
  Uint8List _processMarkdown(Uint8List data) {
    try {
      // Convert bytes to string
      final markdownText = String.fromCharCodes(data);

      // Convert markdown to HTML using the markdown package
      final html =
          '''
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8">
            <title>Markdown Preview</title>
            <style>
              body {
                font-family: -apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                line-height: 1.6;
                padding: 20px;
                max-width: 980px;
                margin: 0 auto;
              }
              pre {
                background: #f5f5f5;
                padding: 15px;
                border-radius: 5px;
                overflow-x: auto;
              }
              code {
                background: #f5f5f5;
                padding: 2px 5px;
                border-radius: 3px;
              }
              img {
                max-width: 100%;
              }
            </style>
          </head>
          <body>
            ${md.markdownToHtml(markdownText)}
          </body>
        </html>
      ''';

      return Uint8List.fromList(html.codeUnits);
    } catch (e, stackTrace) {
      _logger.error('Error processing markdown', e, stackTrace);
      return data; // Return original data if conversion fails
    }
  }

  /// Processes CAR (Content Addressable aRchive) archive content
  Uint8List _processCarArchive(Uint8List data) {
    try {
      // Generate a simple HTML viewer for CAR archive contents
      final html =
          '''
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8">
            <title>CAR Archive Preview</title>
            <style>
              body {
                font-family: system-ui, -apple-system, sans-serif;
                padding: 20px;
                max-width: 980px;
                margin: 0 auto;
              }
              .car-info {
                background: #f5f5f5;
                padding: 20px;
                border-radius: 8px;
                margin-bottom: 20px;
              }
              .warning {
                color: #856404;
                background-color: #fff3cd;
                border: 1px solid #ffeeba;
                padding: 12px;
                border-radius: 4px;
                margin-bottom: 20px;
              }
            </style>
          </head>
          <body>
            <div class="car-info">
              <h2>CAR Archive</h2>
              <p>Size: ${_formatSize(data.length)}</p>
            </div>
            <div class="warning">
              This is a CAR (Content Addressable aRchive) file. 
              It contains IPFS blocks and should be processed by an IPFS node.
            </div>
          </body>
        </html>
      ''';

      return Uint8List.fromList(html.codeUnits);
    } catch (e, stackTrace) {
      _logger.error('Error processing CAR archive', e, stackTrace);
      return data; // Return original data if processing fails
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Detects MIME type from content using magic numbers
  String? _detectFromContent(Uint8List data) {
    if (data.length < 4) return null;

    // Check for common file signatures
    if (_startsWith(data, [0x89, 0x50, 0x4E, 0x47])) {
      return 'image/png';
    }
    if (_startsWith(data, [0xFF, 0xD8, 0xFF])) {
      return 'image/jpeg';
    }
    if (_startsWith(data, [0x47, 0x49, 0x46])) {
      return 'image/gif';
    }
    if (_startsWith(data, [0x25, 0x50, 0x44, 0x46])) {
      return 'application/pdf';
    }

    // Try to detect text content
    if (_isTextContent(data)) {
      return 'text/plain';
    }

    return null;
  }

  /// Checks if data starts with the given bytes
  bool _startsWith(Uint8List data, List<int> signature) {
    if (data.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (data[i] != signature[i]) return false;
    }
    return true;
  }

  /// Checks if content appears to be text
  bool _isTextContent(Uint8List data) {
    final sampleSize = data.length.clamp(0, 512);
    var textChars = 0;

    for (var i = 0; i < sampleSize; i++) {
      final byte = data[i];
      if ((byte >= 32 && byte <= 126) || // ASCII printable
          (byte == 9) || // Tab
          (byte == 10) || // LF
          (byte == 13)) {
        // CR
        textChars++;
      }
    }

    return textChars / sampleSize > 0.8; // 80% text characters threshold
  }

  /// Extracts the path from the current request context
  String? _extractPathFromRequest() {
    try {
      // Get the current zone's request context
      final context = Zone.current[#requestContext];
      if (context == null) return '/';

      // Extract path from request URI
      final uri = context['uri'] as Uri?;
      if (uri == null) return '/';

      // Clean and normalize the path
      var path = uri.path;

      // Remove /ipfs/{cid} prefix if present
      final ipfsPrefix = RegExp(r'^/ipfs/[^/]+/?');
      path = path.replaceFirst(ipfsPrefix, '/');

      // Ensure path starts with / and remove trailing /
      path = '/${path.trim()}/'.replaceAll(RegExp(r'/+'), '/');
      if (path.length > 1) {
        path = path.substring(0, path.length - 1);
      }

      return path;
    } catch (e, stackTrace) {
      _logger.error('Error extracting path from request', e, stackTrace);
      return '/';
    }
  }

  /// Caches the content type mapping for a CID
  Future<void> cacheContentType(String cidStr, String contentType) async {
    try {
      // Create a simple in-memory cache or use a persistent storage solution
      // For now, we'll just store in memory since the cache would be cleared on restart anyway
      _contentTypeCache[cidStr] = contentType;
    } catch (e, stackTrace) {
      _logger.error(
        'Error caching content type for CID $cidStr',
        e,
        stackTrace,
      );
    }
  }
}
