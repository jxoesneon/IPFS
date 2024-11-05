import 'dart:typed_data';
import 'directory_parser.dart';
import 'package:mime/mime.dart';
import '../../core/data_structures/block.dart';

/// Handles content type detection and processing for IPFS gateway responses
class ContentTypeHandler {
  static const _defaultType = 'application/octet-stream';
  static final _mimeResolver = MimeTypeResolver()
    ..addExtension('md', 'text/markdown')
    ..addExtension('ipfs', 'application/vnd.ipfs.car')
    ..addExtension('car', 'application/vnd.ipfs.car');

  final _directoryParser = DirectoryParser();

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
    } catch (e) {
      print('Error generating directory listing: $e');
      return Uint8List.fromList('Error: Failed to generate directory listing'.codeUnits);
    }
  }

  /// Processes markdown content
  Uint8List _processMarkdown(Uint8List data) {
    // TODO: Implement markdown to HTML conversion
    return data;
  }

  /// Processes CAR archive content
  Uint8List _processCarArchive(Uint8List data) {
    // TODO: Implement CAR archive processing if needed
    return data;
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
          (byte == 13)) { // CR
        textChars++;
      }
    }
    
    return textChars / sampleSize > 0.8; // 80% text characters threshold
  }

  String? _extractPathFromRequest() {
    // TODO: Implement path extraction from request context
    return '/';
  }
} 