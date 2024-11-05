import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../core/data_structures/link.dart';
import '../../core/data_structures/block.dart';
import '../../core/data_structures/unixfs.dart';
import '../../core/data_structures/directory.dart';
import '../../proto/generated/dht/directory.pb.dart';
import '../../services/gateway/file_preview_handler.dart';
import '../../services/gateway/lazy_preview_handler.dart';

/// Parses and formats IPFS directory listings with enhanced metadata
class DirectoryParser {
  final _dateFormatter = DateFormat('MMM dd, yyyy HH:mm');
  final _previewHandler = FilePreviewHandler();
  final _lazyPreviewHandler = LazyPreviewHandler();
  
  /// Parses a block containing a directory listing
  DirectoryHandler parseDirectoryBlock(Block block) {
    if (block.cid.codec != 'dag-pb') {
      throw FormatException('Invalid directory block codec: ${block.cid.codec}');
    }

    final directory = Directory.fromBuffer(block.data);
    return DirectoryHandler(directory.path);
  }

  /// Generates an HTML representation of the directory listing with enhanced metadata
  String generateHtmlListing(DirectoryHandler directory, String currentPath) {
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html>')
      ..writeln('<head>')
      ..writeln('<title>IPFS Directory: $currentPath</title>')
      ..writeln('<style>')
      ..writeln(_generateStyles())
      ..writeln(_lazyPreviewHandler.generateLazyLoadStyles())
      ..writeln('</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<div class="header">')
      ..writeln('<h1>Directory listing for $currentPath</h1>')
      ..writeln('</div>')
      ..writeln('<div class="entry header-row">')
      ..writeln('<span></span>') // Icon space
      ..writeln('<span>Name</span>')
      ..writeln('<span>Size</span>')
      ..writeln('<span>Modified</span>')
      ..writeln('<span>Type</span>')
      ..writeln('</div>');

    // Add parent directory link if not at root
    if (currentPath != '/') {
      buffer.writeln(_createEntryHtml(
        name: '..',
        size: '',
        type: 'directory',
        timestamp: 0,
        metadata: {},
        isParent: true,
      ));
    }

    // Get and sort entries
    final entries = directory.listEntries()
      ..sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });

    // Add entries to the listing
    for (final entry in entries) {
      buffer.writeln(_createEntryHtml(
        name: entry.name,
        size: _formatSize(entry.size.toInt()),
        type: entry.isDirectory ? 'directory' : _getFileType(entry),
        timestamp: entry.timestamp,
        metadata: entry.metadata ?? {},
        isParent: false,
      ));
    }

    buffer
      ..writeln(_lazyPreviewHandler.generateLazyLoadScript())
      ..writeln('</body>')
      ..writeln('</html>');

    return buffer.toString();
  }

  String _createEntryHtml({
    required String name,
    required String size,
    required String type,
    required int timestamp,
    required Map<String, String> metadata,
    required bool isParent,
  }) {
    final icon = _getIcon(type);
    final href = isParent ? '../' : Uri.encodeComponent(name);
    final preview = !isParent ? _generatePreviewIfSupported(name, type) : '';
    
    return '''
      <div class="entry">
        <span class="icon">$icon</span>
        <a class="name" href="$href">
          $name
          ${_formatMetadataTooltip(metadata)}
        </a>
        <span class="size">$size</span>
        <span class="date">$date</span>
        <span class="type">
          <span class="permissions">$permissions</span>
        </span>
        $preview
      </div>
    ''';
  }

  String _formatMetadataTooltip(Map<String, String> metadata) {
    if (metadata.isEmpty) return '';
    
    final tooltipContent = metadata.entries
        .where((e) => !['mode', 'size'].contains(e.key))
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    
    return tooltipContent.isEmpty ? '' : 
        '<span class="metadata" title="$tooltipContent">ℹ️</span>';
  }

  String _getIcon(String type) {
    switch (type) {
      case 'directory':
        return '📁';
      case 'image':
        return '🖼️';
      case 'video':
        return '🎥';
      case 'audio':
        return '🎵';
      case 'text':
        return '📄';
      case 'application':
        return '📦';
      default:
        return '📄';
    }
  }

  String _getFileType(DirectoryEntry entry) {
    final extension = entry.name.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'video';
      case 'mp3':
      case 'wav':
      case 'ogg':
        return 'audio';
      case 'txt':
      case 'md':
      case 'json':
        return 'text';
      default:
        return 'file';
    }
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return '';
    
    final units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  String _generatePreviewIfSupported(String name, String type) {
    final contentType = _getContentType(name);
    if (!_previewHandler.isSupportedType(contentType)) {
      return '';
    }
    
    try {
      final preview = _previewHandler.generatePreview(
        _getCurrentBlock(),
        contentType,
        maxSize: 1024 * 1024 // 1MB limit for directory listing previews
      );
      return preview ?? '';
    } catch (e) {
      print('Error generating preview for $name: $e');
      return '';
    }
  }
} 