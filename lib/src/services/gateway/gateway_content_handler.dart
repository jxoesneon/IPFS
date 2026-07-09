// lib/src/services/gateway/gateway_content_handler.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';

import 'gateway_directory_handler.dart';

/// Serves content paths for the IPFS gateway.
class GatewayContentHandler {
  /// Creates a content handler backed by a block store and a directory handler.
  GatewayContentHandler({
    required this.blockStore,
    required this.directoryHandler,
  });

  /// The block store used to retrieve blocks.
  final BlockStore blockStore;

  /// The handler used to render and navigate directories.
  final GatewayDirectoryHandler directoryHandler;

  /// Serves content for the requested CID and optional sub-path.
  Future<Response> serveContent(
    String cidStr,
    String subPath,
    Request request,
  ) async {
    final block = await _getBlockByCid(cidStr);
    if (block == null) {
      return Response.notFound('Block not found');
    }

    try {
      final pbNode = PBNode.fromBuffer(block.data);
      if (pbNode.hasData()) {
        final unixfsData = Data.fromBuffer(pbNode.data);

        if (unixfsData.type == Data_DataType.Directory) {
          if (subPath.isEmpty) {
            final indexCid = directoryHandler.findIndexHtml(pbNode);
            if (indexCid != null) {
              return serveContent(indexCid.encode(), '', request);
            }
            return directoryHandler.renderDirectory(cidStr, pbNode, request);
          } else {
            return directoryHandler.navigateDirectory(
              cidStr,
              pbNode,
              subPath,
              request,
              serveContentCallback: serveContent,
              resolveBlock: getBlockByCid,
            );
          }
        }

        if (unixfsData.type == Data_DataType.HAMTShard) {
          if (subPath.isEmpty) {
            // HAMT shard root: render the direct links as a basic directory
            // listing. Full recursive traversal would require walking the whole
            // shard tree, which is left to future work while preserving the
            // spec-aligned HAMT builder.
            return directoryHandler.renderDirectory(cidStr, pbNode, request);
          } else {
            return directoryHandler.navigateDirectory(
              cidStr,
              pbNode,
              subPath,
              request,
              serveContentCallback: serveContent,
              resolveBlock: getBlockByCid,
            );
          }
        }

        if (unixfsData.type == Data_DataType.File) {
          return _serveFile(unixfsData, cidStr, request);
        }
      }
    } catch (_) {
      // Not a valid UnixFS node; serve as raw block.
    }

    return _serveRawBlock(block, cidStr, request);
  }

  Response _serveFile(Data unixfsData, String cidStr, Request request) {
    final data = Uint8List.fromList(unixfsData.data);
    final contentType = _detectContentType(data);
    final headers = {
      'content-type': contentType,
      'content-length': data.length.toString(),
      'x-ipfs-path': '/ipfs/$cidStr',
      'x-content-type-options': 'nosniff',
      'cache-control': 'public, max-age=29030400, immutable',
    };

    final rangeHeader = request.headers['range'];
    if (rangeHeader != null) {
      return _serveRange(data, rangeHeader, headers);
    }

    return Response.ok(data, headers: headers);
  }

  Response _serveRawBlock(Block block, String cidStr, Request request) {
    final headers = {
      'content-type': 'application/octet-stream',
      'content-length': block.data.length.toString(),
      'x-ipfs-path': '/ipfs/$cidStr',
      'x-content-type-options': 'nosniff',
      'cache-control': 'public, max-age=29030400, immutable',
    };

    final rangeHeader = request.headers['range'];
    if (rangeHeader != null) {
      return _serveRange(block.data, rangeHeader, headers);
    }

    return Response.ok(block.data, headers: headers);
  }

  Response _serveRange(
    List<int> data,
    String rangeHeader,
    Map<String, String> baseHeaders,
  ) {
    final rangeMatch = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
    if (rangeMatch == null) {
      return Response(416, body: 'Invalid range');
    }

    final start = int.tryParse(rangeMatch.group(1) ?? '');
    final endStr = rangeMatch.group(2);
    final end = endStr != null && endStr.isNotEmpty
        ? int.tryParse(endStr)
        : data.length - 1;

    if (start == null || end == null || start < 0 || end < 0 || start > end) {
      return Response(416, body: 'Range not satisfiable');
    }

    if (start >= data.length) {
      return Response(416, body: 'Range not satisfiable');
    }

    final effectiveEnd = end < data.length ? end : data.length - 1;
    final rangeData = data.sublist(start, effectiveEnd + 1);
    final headers = Map<String, String>.from(baseHeaders);
    headers['content-length'] = rangeData.length.toString();
    headers['content-range'] = 'bytes $start-$effectiveEnd/${data.length}';

    return Response(206, body: rangeData, headers: headers);
  }

  String _detectContentType(List<int> data) {
    final mimeType = lookupMimeType('', headerBytes: data);
    if (mimeType != null) {
      return mimeType;
    }
    try {
      utf8.decode(data);
      return 'text/plain; charset=utf-8';
    } catch (_) {
      return 'application/octet-stream';
    }
  }

  /// Returns the block for [cidStr] from the block store, or null if not found
  /// or if an error occurs.
  Future<Block?> getBlockByCid(String cidStr) async {
    try {
      final response = await blockStore.getBlock(cidStr);
      if (response.found) {
        return Block.fromProto(response.block);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Resolves [subPath] under [rootCid] and returns the resulting CID and block.
  /// If the path cannot be resolved, the returned block is null.
  Future<(CID, Block?)> resolveSubPath(CID rootCid, String subPath) async {
    var currentCid = rootCid;
    var currentBlock = await getBlockByCid(rootCid.encode());

    if (subPath.trim().isEmpty) {
      return (currentCid, currentBlock);
    }

    final parts = subPath.split('/').where((p) => p.isNotEmpty).toList();
    for (final part in parts) {
      if (currentBlock == null) {
        return (currentCid, null);
      }
      final next = await directoryHandler.findChildCid(
        currentBlock,
        part,
        resolveBlock: getBlockByCid,
      );
      if (next == null) {
        return (currentCid, null);
      }
      currentCid = next;
      currentBlock = await getBlockByCid(currentCid.encode());
    }

    return (currentCid, currentBlock);
  }

  Future<Block?> _getBlockByCid(String cidStr) async => getBlockByCid(cidStr);
}
