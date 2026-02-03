// lib/src/services/gateway/gateway_handler.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';

/// Resolver function for IPNS names (returns CID)
typedef IpnsResolver = Future<String> Function(String name);

/// Handles IPFS Gateway HTTP requests following the IPFS Gateway specs.
/// See: https://specs.ipfs.tech/http-gateways/
class GatewayHandler {
  /// Creates a gateway handler with a blockstore and optional IPNS resolver.
  GatewayHandler(this.blockStore, {this.ipnsResolver});

  /// The block store for retrieving content.
  final BlockStore blockStore;

  /// Optional resolver for IPNS names.
  final IpnsResolver? ipnsResolver;

  final _logger = Logger('GatewayHandler');

  /// Handles path-based gateway requests (/ipfs/ and /ipns/)
  Future<Response> handlePath(Request request) async {
    final path = request.url.path;

    // Parse IPFS path
    if (path.startsWith('ipfs/')) {
      final parts = path.substring(5).split('/');
      final cidStr = parts[0];
      final subPath = parts.length > 1 ? parts.sublist(1).join('/') : '';

      try {
        return await _serveContent(cidStr, subPath, request);
      } catch (e, stackTrace) {
        _logger.error('Error serving content for $cidStr', e, stackTrace);
        return Response.internalServerError(body: 'Error: $e');
      }
    }

    if (path.startsWith('ipns/')) {
      if (ipnsResolver == null) {
        return Response(501, body: 'IPNS resolution disabled');
      }

      final parts = path.substring(5).split('/');
      final name = parts[0];
      final subPath = parts.length > 1 ? parts.sublist(1).join('/') : '';

      try {
        final cid = await ipnsResolver!(name);
        // Redirect to /ipfs/<custom resolved cid>/<subPath> ?
        // Or serve content directly.
        // Usually Gateways redirect /ipns/ to /ipfs/ or serve content transparently.
        // Serving transparently:
        return await _serveContent(cid, subPath, request);
      } catch (e) {
        _logger.warning('Failed to resolve IPNS name $name: $e');
        return Response.notFound('IPNS name not found: $name');
      }
    }

    return Response.notFound('Invalid IPFS path');
  }

  /// Serves content for a given CID and optional sub-path
  Future<Response> _serveContent(
    String cidStr,
    String subPath,
    Request request,
  ) async {
    final block = await _getBlockByCid(cidStr);
    if (block == null) {
      return Response.notFound('Block not found');
    }

    // Try to parse as UnixFS
    try {
      final pbNode = PBNode.fromBuffer(block.data);
      if (pbNode.hasData()) {
        final unixfsData = Data.fromBuffer(pbNode.data);

        // Handle directories
        if (unixfsData.type == Data_DataType.Directory) {
          if (subPath.isEmpty) {
            return _renderDirectory(cidStr, pbNode, request);
          } else {
            // Navigate to sub-path
            return await _navigateDirectory(cidStr, pbNode, subPath, request);
          }
        }

        // Handle files
        if (unixfsData.type == Data_DataType.File) {
          return _serveFile(unixfsData, pbNode, cidStr, request);
        }
      }
    } catch (e) {
      // Not UnixFS, serve as raw block
    }

    // Serve raw block
    return _serveRaw(block, cidStr, request);
  }

  /// Serves a UnixFS file
  Response _serveFile(
    Data unixfsData,
    PBNode pbNode,
    String cidStr,
    Request request,
  ) {
    final data = Uint8List.fromList(unixfsData.data);
    final contentType = _detectContentType(data);

    final headers = {
      'Content-Type': contentType,
      'Content-Length': data.length.toString(),
      'X-IPFS-Path': '/ipfs/$cidStr',
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'public, max-age=29030400, immutable',
    };

    // Handle range requests
    final rangeHeader = request.headers['range'];
    if (rangeHeader != null) {
      return _serveRange(data, rangeHeader, headers);
    }

    return Response.ok(data, headers: headers);
  }

  /// Serves raw block data
  Response _serveRaw(Block block, String cidStr, Request request) {
    final headers = {
      'Content-Type': 'application/octet-stream',
      'Content-Length': block.data.length.toString(),
      'X-IPFS-Path': '/ipfs/$cidStr',
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'public, max-age=29030400, immutable',
    };

    return Response.ok(block.data, headers: headers);
  }

  /// Renders a directory as HTML
  Response _renderDirectory(String cidStr, PBNode pbNode, Request request) {
    final html = StringBuffer();
    html.writeln('<!DOCTYPE html>');
    html.writeln('<html><head><meta charset="utf-8">');
    html.writeln('<title>Index of /ipfs/$cidStr</title>');
    html.writeln('<style>');
    html.writeln('body { font-family: monospace; margin: 2em; }');
    html.writeln('h1 { font-size: 1.5em; }');
    html.writeln('table { border-collapse: collapse; width: 100%; }');
    html.writeln(
      'td, th { padding: 0.5em; text-align: left; border-bottom: 1px solid #ddd; }',
    );
    html.writeln('a { color: #0066cc; text-decoration: none; }');
    html.writeln('a:hover { text-decoration: underline; }');
    html.writeln('</style></head><body>');
    html.writeln('<h1>Index of /ipfs/$cidStr</h1>');
    html.writeln('<table>');
    html.writeln(
      '<thead><tr><th>Name</th><th>Size</th><th>Type</th></tr></thead>',
    );
    html.writeln('<tbody>');

    for (final link in pbNode.links) {
      final name = link.name;
      // SEC-005: Escape untrusted file names to prevent XSS attacks
      final escapedName = const HtmlEscape().convert(name);
      final size = link.size.toInt();
      final linkCid = CID.fromBytes(Uint8List.fromList(link.hash));
      html.writeln('<tr>');
      html.writeln(
        '  <td><a href="/ipfs/${linkCid.encode()}">$escapedName</a></td>',
      );
      html.writeln('  <td>${_formatSize(size.toInt())}</td>');
      html.writeln('  <td>-</td>');
      html.writeln('</tr>');
    }

    html.writeln('</tbody></table></body></html>');

    return Response.ok(
      html.toString(),
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'X-IPFS-Path': '/ipfs/$cidStr',
        'Cache-Control': 'public, max-age=29030400, immutable',
      },
    );
  }

  /// Navigates to a sub-path within a directory
  Future<Response> _navigateDirectory(
    String rootCid,
    PBNode directory,
    String subPath,
    Request request,
  ) async {
    final pathParts = subPath.split('/');
    final targetName = pathParts[0];
    final remainingPath = pathParts.length > 1
        ? pathParts.sublist(1).join('/')
        : '';

    // Find the link with matching name
    for (final link in directory.links) {
      final linkName = link.name;
      if (linkName == targetName) {
        final linkCid = CID.fromBytes(Uint8List.fromList(link.hash));
        return await _serveContent(linkCid.encode(), remainingPath, request);
      }
    }

    return Response.notFound('Path not found: $subPath');
  }

  /// Serves a byte range from data
  Response _serveRange(
    List<int> data,
    String rangeHeader,
    Map<String, String> baseHeaders,
  ) {
    // Parse range header: "bytes=start-end"
    final rangeMatch = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
    if (rangeMatch == null) {
      return Response(416, body: 'Invalid range'); // Range Not Satisfiable
    }

    final start = int.parse(rangeMatch.group(1)!);
    final endStr = rangeMatch.group(2);
    final end = endStr != null && endStr.isNotEmpty
        ? int.parse(endStr)
        : data.length - 1;

    if (start >= data.length || end >= data.length || start > end) {
      return Response(416, body: 'Range not satisfiable');
    }

    final rangeData = data.sublist(start, end + 1);
    final headers = Map<String, String>.from(baseHeaders);
    headers['Content-Length'] = rangeData.length.toString();
    headers['Content-Range'] = 'bytes $start-$end/${data.length}';

    return Response(206, body: rangeData, headers: headers); // Partial Content
  }

  /// Handles subdomain-based gateway requests (CID.ipfs.localhost)
  Future<Response> handleSubdomain(Request request) async {
    final host = request.headers['host'];
    if (host == null) return Response.badRequest(body: 'Missing host header');

    // Parse CID from subdomain
    final parts = host.split('.');
    if (parts.length >= 3 && parts[parts.length - 2] == 'ipfs') {
      final cidStr = parts[0];
      final path = request.url.path;

      try {
        return await _serveContent(cidStr, path, request);
      } catch (e) {
        return Response.internalServerError(body: 'Error: $e');
      }
    }

    return Response.badRequest(body: 'Invalid IPFS subdomain');
  }

  /// Detects content type from file data
  String _detectContentType(List<int> data) {
    // Try MIME type detection
    final mimeType = lookupMimeType('', headerBytes: data);
    if (mimeType != null) {
      return mimeType;
    }

    // Check for text
    try {
      utf8.decode(data);
      return 'text/plain; charset=utf-8';
    } catch (e) {
      return 'application/octet-stream';
    }
  }

  /// Formats file size for display
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Helper method to get a block by CID string
  Future<Block?> _getBlockByCid(String cidStr) async {
    try {
      final response = await blockStore.getBlock(cidStr);
      if (response.found) {
        return Block.fromProto(response.block);
      }
    } catch (e, stackTrace) {
      _logger.error('Error getting block $cidStr', e, stackTrace);
    }
    return null;
  }
}

