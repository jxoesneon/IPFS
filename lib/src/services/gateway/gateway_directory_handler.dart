// lib/src/services/gateway/gateway_directory_handler.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_hamt.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:shelf/shelf.dart';

/// Resolves an encoded CID string to a [Block] from the block store.
typedef BlockResolver = Future<Block?> Function(String cidStr);

/// Handles rendering and navigation of UnixFS directory nodes for the IPFS
/// gateway.
class GatewayDirectoryHandler {
  /// Creates a directory handler.
  GatewayDirectoryHandler();

  /// Renders a directory listing as HTML.
  ///
  /// When [parentPath] is provided, an "../" entry is included so the user can
  /// navigate to the parent directory. This mirrors the behavior of path-style
  /// IPFS gateways.
  Response renderDirectory(
    String cidStr,
    PBNode pbNode,
    Request request, {
    String parentPath = '',
  }) {
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
    html.writeln('<thead><tr><th>Name</th><th>Size</th></tr></thead>');
    html.writeln('<tbody>');

    if (parentPath.isNotEmpty) {
      final escapedParent = const HtmlEscape().convert(parentPath);
      html.writeln('<tr>');
      html.writeln('  <td><a href="$escapedParent">../</a></td>');
      html.writeln('  <td>-</td>');
      html.writeln('</tr>');
    }

    for (final link in pbNode.links) {
      final name = link.name;
      final escapedName = const HtmlEscape().convert(name);
      final size = link.size.toInt();
      final linkCid = CID.fromBytes(Uint8List.fromList(link.hash));
      html.writeln('<tr>');
      html.writeln(
        '  <td><a href="/ipfs/${linkCid.encode()}">$escapedName</a></td>',
      );
      html.writeln('  <td>${_formatSize(size)}</td>');
      html.writeln('</tr>');
    }

    html.writeln('</tbody></table></body></html>');

    return Response.ok(
      html.toString(),
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'x-ipfs-path': '/ipfs/$cidStr',
        'cache-control': 'public, max-age=29030400, immutable',
      },
    );
  }

  /// Returns the CID of an `index.html` child link if one exists in [pbNode],
  /// or null otherwise.
  CID? findIndexHtml(PBNode pbNode) {
    final link = findLinkByName(pbNode.links, 'index.html');
    if (link == null) return null;
    return CID.fromBytes(Uint8List.fromList(link.hash));
  }

  /// Navigates to a sub-path within a directory and calls the provided
  /// callback to serve the matching child content.
  ///
  /// [resolveBlock] is used when traversing HAMT-sharded directories; flat
  /// directories do not require it.
  Future<Response> navigateDirectory(
    String cidStr,
    PBNode pbNode,
    String subPath,
    Request request, {
    required Future<Response> Function(
      String cidStr,
      String subPath,
      Request request,
    )
    serveContentCallback,
    BlockResolver? resolveBlock,
  }) async {
    final pathParts = subPath.split('/').where((p) => p.isNotEmpty).toList();
    if (pathParts.isEmpty) {
      return renderDirectory(cidStr, pbNode, request);
    }

    final block = Block(cid: CID.decode(cidStr), data: pbNode.writeToBuffer());
    final childCid = await findChildCid(
      block,
      pathParts.first,
      resolveBlock: resolveBlock,
    );
    if (childCid == null) {
      return Response.notFound('Path not found: $subPath');
    }

    final remainingPath = pathParts.length > 1
        ? pathParts.sublist(1).join('/')
        : '';
    return serveContentCallback(childCid.encode(), remainingPath, request);
  }

  /// Finds the child CID for a named link within a DAG-PB block.
  ///
  /// For HAMT-sharded directories, [resolveBlock] must be provided so that
  /// sub-shards can be fetched and recursed into.
  Future<CID?> findChildCid(
    Block block,
    String name, {
    BlockResolver? resolveBlock,
  }) async {
    if (block.cid.codec != 'dag-pb') {
      return null;
    }
    try {
      final node = UnixFSNode.fromBlock(block);
      if (node.isHAMTShard) {
        if (resolveBlock == null) return null;
        return _resolveHAMTChild(node, name, resolveBlock, 0);
      }
      final link = findLinkByName(node.pbNode.links, name);
      if (link != null) {
        return CID.fromBytes(Uint8List.fromList(link.hash));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<CID?> _resolveHAMTChild(
    UnixFSNode node,
    String name,
    BlockResolver resolveBlock,
    int level,
  ) async {
    final link = resolveHAMTSegment(node, name, level);
    if (link == null) return null;

    final childCid = CID.fromBytes(Uint8List.fromList(link.hash));
    final prefixWidth = hamtPrefixWidth(node.fanout);
    if (prefixWidth == 0) return null;

    // A link whose name is exactly the hex prefix points to a sub-shard.
    if (link.name.length == prefixWidth) {
      final childBlock = await resolveBlock(childCid.encode());
      if (childBlock == null) return null;
      final childNode = UnixFSNode.fromBlock(childBlock);
      return _resolveHAMTChild(childNode, name, resolveBlock, level + 1);
    }

    return childCid;
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
