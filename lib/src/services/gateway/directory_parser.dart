import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/services/gateway/file_preview_handler.dart';
import 'package:dart_ipfs/src/services/gateway/lazy_preview_handler.dart';
import 'package:intl/intl.dart';

/// Handles directory operations and metadata for IPFS directory listings
class DirectoryHandler {

  DirectoryHandler(this.path);
  final String path;
  final List<DirectoryEntry> _entries = [];

  /// Adds an entry to the directory
  void addEntry(DirectoryEntry entry) {
    _entries.add(entry);
  }

  /// Lists all entries in the directory
  List<DirectoryEntry> listEntries() {
    return List.unmodifiable(_entries);
  }
}

/// Represents a single directory entry with metadata
class DirectoryEntry {

  DirectoryEntry({
    required this.name,
    required this.size,
    required this.isDirectory,
    required this.timestamp,
    this.metadata,
  });
  final String name;
  final int size;
  final bool isDirectory;
  final int timestamp;
  final Map<String, String>? metadata;
}

/// Parses and formats IPFS directory listings with enhanced metadata
class DirectoryParser {
  final _dateFormatter = DateFormat('MMM dd, yyyy HH:mm');
  final _previewHandler = FilePreviewHandler();
  final _lazyPreviewHandler = LazyPreviewHandler();
  Block? _currentBlock;

  /// Parses a block containing a directory listing
  DirectoryHandler parseDirectoryBlock(Block block) {
    if (block.cid.codec != 'dag-pb') {
      throw FormatException(
        'Invalid directory block codec: ${block.cid.codec}',
      );
    }

    _currentBlock = block;

    // Parse standard UnixFS Directory
    try {
      final pbNode = PBNode.fromBuffer(block.data);

      // Check UnixFS Data
      if (pbNode.hasData()) {
        try {
          final unixFsData = Data.fromBuffer(pbNode.data);
          if (unixFsData.type != Data_DataType.Directory &&
              unixFsData.type != Data_DataType.HAMTShard) {
            throw FormatException(
              'Block is not a UnixFS Directory (Type: ${unixFsData.type})',
            );
          }
        } catch (e) {
          // If data fails to parse as UnixFS, it might not be a UnixFS directory
          throw FormatException('Failed to parse UnixFS data: $e');
        }
      }

      // Create Handler (Path is unknown from the block itself, defaults to root or empty)
      final handler = DirectoryHandler(
        '/${block.cid.encode()}',
      ); // Use CID as placeholder path

      for (final link in pbNode.links) {
        // Determine if link is directory?
        // In standard MerkleDAG, the link doesn't strictly say if target is directory without fetching it.
        // However, typical listings might guess or we fetch?
        // For now, let's assume unknown or use Tsize.
        // But strict Gateway usually fetches metadata or just lists them.
        // The old code assumed `isDirectory` was in the link metadata?
        // PBLink doesn't have metadata in standard spec (except Name, Hash, Tsize).
        // We will default isDirectory to false or try to infer.

        // Standard generic ls usually requires resolving the link to know type,
        // OR assuming everything is a file/dir based on context.
        // For a simple list, we treat everything as a generic entry.
        // But the UI wants icons.

        handler.addEntry(
          DirectoryEntry(
            name: link.name,
            size: link.size.toInt(),
            isDirectory:
                false, // Cannot know without fetching child block in standard IPFS
            timestamp: 0, // Not stored in standard link
            metadata: {},
          ),
        );
      }

      return handler;
    } catch (e) {
      throw FormatException('Failed to parse PBNode: $e');
    }
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
      buffer.writeln(
        _createEntryHtml(
          name: '..',
          size: '',
          type: 'directory',
          timestamp: 0,
          metadata: {},
          isParent: true,
        ),
      );
    }

    // Get and sort entries
    final entries = List<DirectoryEntry>.from(directory.listEntries())
      ..sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });

    // Add entries to the listing
    for (final entry in entries) {
      buffer.writeln(
        _createEntryHtml(
          name: entry.name,
          size: _formatSize(entry.size.toInt()),
          type: entry.isDirectory ? 'directory' : _getFileType(entry),
          timestamp: entry.timestamp,
          metadata: entry.metadata ?? {},
          isParent: false,
        ),
      );
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
    final date = isParent
        ? ''
        : _dateFormatter.format(DateTime.fromMillisecondsSinceEpoch(timestamp));

    return '''
      <div class="entry">
        <span class="icon">$icon</span>
        <a class="name" href="$href">
          $name
          ${_formatMetadataTooltip(metadata)}
        </a>
        <span class="size">$size</span>
        <span class="date">$date</span>
        <span class="type">$type</span>
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

    return tooltipContent.isEmpty
        ? ''
        : '<span class="metadata" title="$tooltipContent">ℹ️</span>';
  }

  String _getIcon(String type) {
    switch (type) {
      case 'directory':
        return '��';
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
        maxSize: 1024 * 1024, // 1MB limit for directory listing previews
      );
      return preview ?? '';
    } catch (e) {
      // print('Error generating preview for $name: $e');
      return '';
    }
  }

  String _generateStyles() {
    return '''
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
        margin: 0;
        padding: 20px;
        background: #f5f5f5;
      }
      .header {
        background: #fff;
        padding: 20px;
        border-radius: 8px;
        margin-bottom: 20px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      .header h1 {
        margin: 0;
        font-size: 24px;
        color: #333;
      }
      .entry {
        display: grid;
        grid-template-columns: 30px 1fr 100px 180px 100px;
        gap: 10px;
        align-items: center;
        padding: 12px;
        background: #fff;
        border-radius: 4px;
        margin-bottom: 8px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.05);
      }
      .header-row {
        font-weight: bold;
        color: #666;
        border-bottom: 2px solid #eee;
        padding-bottom: 8px;
        margin-bottom: 16px;
      }
      .icon {
        font-size: 18px;
      }
      .name {
        color: #2196f3;
        text-decoration: none;
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .name:hover {
        text-decoration: underline;
      }
      .size {
        color: #666;
        text-align: right;
      }
      .date {
        color: #666;
      }
      .type {
        color: #666;
      }
      .metadata {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        font-size: 14px;
        color: #666;
        cursor: help;
      }
      .preview-container {
        grid-column: 1 / -1;
        margin-top: 10px;
        padding: 10px;
        background: #f8f9fa;
        border-radius: 4px;
        overflow: hidden;
      }
      .preview-image {
        max-width: 200px;
        max-height: 150px;
        object-fit: contain;
      }
      .preview-text {
        max-height: 150px;
        overflow-y: auto;
        margin: 0;
        padding: 10px;
        background: #fff;
        border-radius: 4px;
        font-size: 13px;
        line-height: 1.4;
      }
    ''';
  }

  Block _getCurrentBlock() {
    if (_currentBlock == null) {
      throw StateError('No block is currently being processed');
    }
    return _currentBlock!;
  }

  String _getContentType(String name) {
    final extension = name.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'html':
      case 'htm':
        return 'text/html';
      case 'json':
        return 'application/json';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
