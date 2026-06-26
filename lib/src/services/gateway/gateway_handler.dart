// lib/src/services/gateway/gateway_handler.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';

/// Resolver function for IPNS names (returns CID).
typedef IpnsResolver = Future<String> Function(String name);

/// Resolver function for IPNS record bytes (returns signed record bytes).
typedef IpnsRecordResolver = Future<Uint8List?> Function(String name);

/// Supported trustless gateway response formats.
enum TrustlessFormat {
  /// Raw block response format.
  raw,

  /// CAR v1 archive response format.
  car,

  /// Signed IPNS record response format.
  ipnsRecord,

  /// Canonical DAG-JSON response format.
  dagJson,

  /// Canonical DAG-CBOR response format.
  dagCbor,
}

/// Handles IPFS Gateway HTTP requests following the IPFS Gateway specs.
/// See: https://specs.ipfs.tech/http-gateways/
class GatewayHandler {
  /// Creates a gateway handler with a blockstore and optional resolvers.
  GatewayHandler(
    this.blockStore, {
    this.ipnsResolver,
    this.ipnsRecordResolver,
    this.bitswapHandler,
    this.denylistService,
    this.metricsCollector,
  });

  /// The block store for retrieving content.
  final BlockStore blockStore;

  /// Optional resolver for IPNS names to CIDs.
  final IpnsResolver? ipnsResolver;

  /// Optional resolver for IPNS record bytes.
  final IpnsRecordResolver? ipnsRecordResolver;

  /// Optional Bitswap handler for retrieving missing blocks from the network.
  final BitswapHandler? bitswapHandler;

  /// Optional denylist service for content blocking.
  final DenylistService? denylistService;

  /// Optional metrics collector for gateway request telemetry.
  ///
  /// TODO: coordinate with the metrics subagent to add a dedicated
  /// `ipfs_gateway_requests_total` counter rather than reusing the generic
  /// protocol metrics stream.
  final MetricsCollector? metricsCollector;

  final _logger = Logger('GatewayHandler');

  /// Default limits for CAR traversal to prevent unbounded resource use.
  static const int _defaultMaxCarDepth = 32;
  static const int _defaultMaxCarBlocks = 10000;

  /// Default TTL for IPNS record Cache-Control when no record TTL is available.
  static const int _defaultIpnsTtlSeconds = 60;

  /// Returns a 451 response if the CID or path is blocked by the denylist.
  ///
  /// Returns `null` when the content is not blocked or no denylist is
  /// configured.
  Response? _checkDenylist(String pathOrCid) {
    final service = denylistService;
    if (service == null || !service.isEnabled) {
      return null;
    }
    if (service.isBlockedByCidString(pathOrCid) ||
        service.isBlockedPath(pathOrCid)) {
      return Response(
        451,
        body: 'Unavailable For Legal Reasons',
        headers: {'Content-Type': 'text/plain'},
      );
    }
    return null;
  }

  /// Records a gateway request metric if a [MetricsCollector] is available.
  ///
  /// This is intentionally a thin wrapper around the existing collector to
  /// avoid duplicating metrics implementation. A dedicated counter API should
  /// be added by the metrics subagent.
  void _recordGatewayRequest(String method, String path, int statusCode) {
    final metrics = metricsCollector;
    if (metrics == null) {
      return;
    }
    try {
      metrics.recordProtocolMetrics('gateway', {
        'method': method,
        'path': path,
        'status_code': statusCode,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.warning('Failed to record gateway metrics', e, stackTrace);
    }
  }

  /// Handles path-based gateway requests (/ipfs/ and /ipns/)
  Future<Response> handlePath(Request request) async {
    final path = request.url.path;
    Response response;

    // Parse IPFS path
    if (path.startsWith('ipfs/')) {
      final parts = path.substring(5).split('/');
      final cidStr = parts[0];
      final subPath = parts.length > 1 ? parts.sublist(1).join('/') : '';

      try {
        final denylisted = _checkDenylist('/ipfs/$cidStr');
        if (denylisted != null) {
          response = denylisted;
        } else {
          final cid = CID.decode(cidStr);
          final format = _detectTrustlessFormat(request);
          if (format != null) {
            response = await _serveTrustless(cid, subPath, format, request);
          } else {
            response = await _serveContent(cidStr, subPath, request);
          }
        }
      } on FormatException catch (e) {
        _logger.warning('Invalid CID in path: $cidStr ($e)');
        response = Response.badRequest(body: 'Invalid CID');
      } catch (e, stackTrace) {
        _logger.error('Error serving content for $cidStr', e, stackTrace);
        response = Response.internalServerError(body: 'Internal server error');
      }
      _recordGatewayRequest(request.method, path, response.statusCode);
      return response;
    }

    if (path.startsWith('ipns/')) {
      final parts = path.substring(5).split('/');
      final name = parts[0];
      final subPath = parts.length > 1 ? parts.sublist(1).join('/') : '';

      try {
        final denylisted = _checkDenylist('/ipns/$name');
        if (denylisted != null) {
          response = denylisted;
        } else {
          final format = _detectTrustlessFormat(request);
          if (format == TrustlessFormat.ipnsRecord) {
            response = await _serveIpnsRecord(name, request);
          } else if (ipnsResolver == null) {
            response = Response(501, body: 'IPNS resolution disabled');
          } else {
            final cid = await ipnsResolver!(name);
            if (format != null) {
              response = await _serveTrustless(
                CID.decode(cid),
                subPath,
                format,
                request,
                ipnsPath: '/ipns/$name',
              );
            } else {
              response = await _serveContent(cid, subPath, request);
            }
          }
        }
      } catch (e) {
        _logger.warning('Failed to resolve IPNS name $name: $e');
        response = Response.notFound('IPNS name not found: $name');
      }
      _recordGatewayRequest(request.method, path, response.statusCode);
      return response;
    }

    response = Response.notFound('Invalid IPFS path');
    _recordGatewayRequest(request.method, path, response.statusCode);
    return response;
  }

  /// Detects the requested trustless response format from the request.
  ///
  /// Query parameter `?format=` takes precedence over the `Accept` header.
  /// Returns `null` when no trustless format is requested.
  TrustlessFormat? _detectTrustlessFormat(Request request) {
    final formatParam = request.url.queryParameters['format'];
    if (formatParam != null) {
      return _parseFormat(formatParam);
    }

    final accept = request.headers['accept'];
    if (accept != null) {
      return _parseAcceptHeader(accept);
    }

    return null;
  }

  /// Parses a `?format=` query value into a trustless format.
  TrustlessFormat? _parseFormat(String value) {
    switch (value) {
      case 'raw':
        return TrustlessFormat.raw;
      case 'car':
        return TrustlessFormat.car;
      case 'ipns-record':
        return TrustlessFormat.ipnsRecord;
      case 'dag-json':
        return TrustlessFormat.dagJson;
      case 'dag-cbor':
        return TrustlessFormat.dagCbor;
      default:
        return null;
    }
  }

  /// Parses the `Accept` header and returns the first supported trustless
  /// media type, or `null` if none is supported.
  TrustlessFormat? _parseAcceptHeader(String accept) {
    const mediaTypeMap = {
      'application/vnd.ipfs.raw-block': TrustlessFormat.raw,
      'application/vnd.ipfs.car': TrustlessFormat.car,
      'application/vnd.ipfs.ipns-record': TrustlessFormat.ipnsRecord,
      'application/vnd.ipld.dag-json': TrustlessFormat.dagJson,
      'application/vnd.ipld.dag-cbor': TrustlessFormat.dagCbor,
    };

    // Split by comma and ignore any q-values; preserve header order.
    final entries = accept.split(',');
    for (final entry in entries) {
      final mediaType = entry.split(';').first.trim().toLowerCase();
      final format = mediaTypeMap[mediaType];
      if (format != null) {
        return format;
      }
    }
    return null;
  }

  /// Dispatches a trustless format request to the appropriate handler.
  Future<Response> _serveTrustless(
    CID cid,
    String subPath,
    TrustlessFormat format,
    Request request, {
    String? ipnsPath,
  }) async {
    final denylisted = _checkDenylist(ipnsPath ?? '/ipfs/${cid.encode()}');
    if (denylisted != null) {
      return denylisted;
    }

    switch (format) {
      case TrustlessFormat.raw:
        return await _serveRawBlock(cid, request, ipnsPath: ipnsPath);
      case TrustlessFormat.car:
        return await _serveCar(cid, subPath, request, ipnsPath: ipnsPath);
      case TrustlessFormat.dagJson:
        return await _serveDagJson(cid, request, ipnsPath: ipnsPath);
      case TrustlessFormat.dagCbor:
        return await _serveDagCbor(cid, request, ipnsPath: ipnsPath);
      case TrustlessFormat.ipnsRecord:
        // ipns-record requests are only handled at /ipns/<name> paths by the
        // caller, so reaching here is an internal error for /ipfs/ paths.
        return Response.badRequest(
          body: 'IPNS record format not supported for /ipfs/ paths',
        );
    }
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

    // Handle range requests
    final rangeHeader = request.headers['range'];
    if (rangeHeader != null) {
      return _serveRange(block.data, rangeHeader, headers);
    }

    return Response.ok(block.data, headers: headers);
  }

  // ---------------------------------------------------------------------------
  // Trustless gateway response handlers
  // ---------------------------------------------------------------------------

  /// Serves the raw block bytes for the requested CID.
  Future<Response> _serveRawBlock(
    CID cid,
    Request request, {
    String? ipnsPath,
  }) async {
    final block = await _getBlockByCid(cid.encode());
    if (block == null) {
      return Response.notFound('Block not found');
    }

    final headers = {
      'Content-Type': 'application/vnd.ipfs.raw-block',
      'Content-Length': block.data.length.toString(),
      'X-IPFS-Path': ipnsPath ?? '/ipfs/${cid.encode()}',
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'public, max-age=29030400, immutable',
    };

    return Response.ok(block.data, headers: headers);
  }

  /// Serves a CAR v1 archive containing the requested CID and reachable DAG.
  Future<Response> _serveCar(
    CID cid,
    String subPath,
    Request request, {
    String? ipnsPath,
  }) async {
    // Resolve sub-path navigation first so we know which target node to archive.
    // The CAR header root is always the originally requested CID.
    final (targetCid, targetBlock) = await _resolveSubPath(cid, subPath);
    if (targetBlock == null) {
      return Response.notFound('Block not found');
    }

    final writer = CarWriter(roots: [cid]);
    final seen = <String>{};

    try {
      await _writeCarSubtree(targetCid, targetBlock, writer, seen, depth: 0);

      // Ensure the originally requested CID is present in the data section.
      if (cid.encode() != targetCid.encode() && !seen.contains(cid.encode())) {
        final rootBlock = await _getBlockByCid(cid.encode());
        if (rootBlock != null) {
          await writer.write(cid, rootBlock.data);
          seen.add(cid.encode());
        }
      }

      final carBytes = await writer.close();
      final headers = {
        'Content-Type': 'application/vnd.ipfs.car',
        'Content-Length': carBytes.length.toString(),
        'Content-Disposition': 'attachment; filename="${cid.encode()}.car"',
        'X-IPFS-Path': ipnsPath ?? '/ipfs/${cid.encode()}',
        'X-Content-Type-Options': 'nosniff',
        'Cache-Control': 'public, max-age=29030400, immutable',
      };
      return Response.ok(carBytes, headers: headers);
    } on CarException catch (e) {
      _logger.warning('CAR generation failed for ${cid.encode()}: $e');
      return Response(416, body: 'CAR generation failed: $e');
    } catch (e, stackTrace) {
      _logger.error('Error generating CAR for ${cid.encode()}', e, stackTrace);
      return Response.internalServerError(body: 'Internal server error');
    }
  }

  /// Recursively writes a node and its reachable DAG into a CAR writer.
  Future<void> _writeCarSubtree(
    CID cid,
    Block block,
    CarWriter writer,
    Set<String> seen, {
    required int depth,
    int maxDepth = _defaultMaxCarDepth,
    int maxBlocks = _defaultMaxCarBlocks,
  }) async {
    if (depth > maxDepth) {
      throw CarException('CAR traversal exceeded maximum depth $maxDepth');
    }
    if (seen.length >= maxBlocks) {
      throw CarException(
        'CAR traversal exceeded maximum block count $maxBlocks',
      );
    }

    final cidStr = cid.encode();
    if (seen.contains(cidStr)) {
      return;
    }
    seen.add(cidStr);
    await writer.write(cid, block.data);

    // Only DAG-PB nodes have navigable links for the full DAG traversal.
    if (block.cid.codec != 'dag-pb') {
      return;
    }

    try {
      final pbNode = PBNode.fromBuffer(block.data);
      for (final link in pbNode.links) {
        final linkCid = CID.fromBytes(Uint8List.fromList(link.hash));
        final childBlock = await _getBlockByCid(linkCid.encode());
        if (childBlock == null) {
          // _getBlockByCid already attempts Bitswap retrieval when available.
          throw CarException(
            'Missing linked block ${linkCid.encode()} during CAR traversal',
          );
        }
        await _writeCarSubtree(
          linkCid,
          childBlock,
          writer,
          seen,
          depth: depth + 1,
        );
      }
    } catch (e) {
      // If we cannot parse the node as DAG-PB, we already wrote the block as
      // a single section and stop recursion.
      if (e is CarException) rethrow;
    }
  }

  /// Serves the signed IPNS record bytes for the requested name.
  Future<Response> _serveIpnsRecord(String name, Request request) async {
    if (ipnsRecordResolver == null) {
      return Response(501, body: 'IPNS record resolution disabled');
    }

    final recordBytes = await ipnsRecordResolver!(name);
    if (recordBytes == null || recordBytes.isEmpty) {
      return Response.notFound('IPNS record not found');
    }

    final maxAge = _ipnsRecordTtl(recordBytes);
    final headers = {
      'Content-Type': 'application/vnd.ipfs.ipns-record',
      'Content-Length': recordBytes.length.toString(),
      'X-IPFS-Path': '/ipns/$name',
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'public, max-age=$maxAge',
    };
    return Response.ok(recordBytes, headers: headers);
  }

  /// Extracts the TTL in seconds from CBOR-encoded IPNS record bytes.
  ///
  /// Falls back to [_defaultIpnsTtlSeconds] if the record cannot be parsed.
  int _ipnsRecordTtl(Uint8List recordBytes) {
    try {
      final record = IPNSRecord.fromCBOR(recordBytes);
      return record.ttl.inSeconds > 0
          ? record.ttl.inSeconds
          : _defaultIpnsTtlSeconds;
    } catch (e) {
      return _defaultIpnsTtlSeconds;
    }
  }

  /// Serves the requested node as canonical DAG-JSON.
  Future<Response> _serveDagJson(
    CID cid,
    Request request, {
    String? ipnsPath,
  }) async {
    final block = await _getBlockByCid(cid.encode());
    if (block == null) {
      return Response.notFound('Block not found');
    }

    try {
      final node = await _decodeBlockAsIpldNode(block);
      final encoded = await DagJsonCodec().encode(node);
      final headers = {
        'Content-Type': 'application/vnd.ipld.dag-json',
        'Content-Length': encoded.length.toString(),
        'X-IPFS-Path': ipnsPath ?? '/ipfs/${cid.encode()}',
        'X-Content-Type-Options': 'nosniff',
        'Cache-Control': 'public, max-age=29030400, immutable',
      };
      return Response.ok(encoded, headers: headers);
    } catch (e, stackTrace) {
      _logger.error(
        'Error encoding DAG-JSON for ${cid.encode()}',
        e,
        stackTrace,
      );
      return Response.internalServerError(body: 'Internal server error');
    }
  }

  /// Serves the requested node as canonical DAG-CBOR.
  Future<Response> _serveDagCbor(
    CID cid,
    Request request, {
    String? ipnsPath,
  }) async {
    final block = await _getBlockByCid(cid.encode());
    if (block == null) {
      return Response.notFound('Block not found');
    }

    try {
      final node = await _decodeBlockAsIpldNode(block);
      final encoded = await DagCborCodec().encode(node);
      final headers = {
        'Content-Type': 'application/vnd.ipld.dag-cbor',
        'Content-Length': encoded.length.toString(),
        'X-IPFS-Path': ipnsPath ?? '/ipfs/${cid.encode()}',
        'X-Content-Type-Options': 'nosniff',
        'Cache-Control': 'public, max-age=29030400, immutable',
      };
      return Response.ok(encoded, headers: headers);
    } catch (e, stackTrace) {
      _logger.error(
        'Error encoding DAG-CBOR for ${cid.encode()}',
        e,
        stackTrace,
      );
      return Response.internalServerError(body: 'Internal server error');
    }
  }

  /// Decodes a block into the canonical IPLD node representation for the codec.
  Future<IPLDNode> _decodeBlockAsIpldNode(Block block) async {
    final codec = block.cid.codec;
    switch (codec) {
      case 'dag-pb':
        return await DagPbCodec().decode(block.data);
      case 'dag-cbor':
        return await DagCborCodec().decode(block.data);
      case 'raw':
        return await RawCodec().decode(block.data);
      default:
        // For unknown codecs, try to interpret as raw bytes; this preserves
        // deterministic responses while avoiding arbitrary failures.
        return await RawCodec().decode(block.data);
    }
  }

  /// Resolves a sub-path relative to the root CID and returns the target CID
  /// and block. If the sub-path is empty or resolution fails, returns the root.
  Future<(CID, Block?)> _resolveSubPath(CID rootCid, String subPath) async {
    if (subPath.isEmpty) {
      final block = await _getBlockByCid(rootCid.encode());
      return (rootCid, block);
    }

    var currentCid = rootCid;
    var currentBlock = await _getBlockByCid(rootCid.encode());
    final parts = subPath.split('/').where((p) => p.isNotEmpty).toList();

    for (final part in parts) {
      if (currentBlock == null) {
        return (currentCid, null);
      }
      final next = await _findChildCid(currentBlock, part);
      if (next == null) {
        return (currentCid, null);
      }
      currentCid = next;
      currentBlock = await _getBlockByCid(currentCid.encode());
    }

    return (currentCid, currentBlock);
  }

  /// Finds the child CID for the named link within a DAG-PB directory.
  Future<CID?> _findChildCid(Block block, String name) async {
    if (block.cid.codec != 'dag-pb') {
      return null;
    }
    try {
      final pbNode = PBNode.fromBuffer(block.data);
      for (final link in pbNode.links) {
        if (link.name == name) {
          return CID.fromBytes(Uint8List.fromList(link.hash));
        }
      }
    } catch (e) {
      _logger.warning('Failed to parse DAG-PB node for path resolution: $e');
    }
    return null;
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
    headers['Content-Length'] = rangeData.length.toString();
    headers['Content-Range'] = 'bytes $start-$effectiveEnd/${data.length}';

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
      Response response;

      try {
        final cid = CID.decode(cidStr);
        final format = _detectTrustlessFormat(request);
        if (format != null) {
          // Subdomain requests only have a root CID, so the sub-path is empty.
          response = await _serveTrustless(cid, path, format, request);
        } else {
          response = await _serveContent(cidStr, path, request);
        }
      } on FormatException catch (e) {
        _logger.warning('Invalid CID in subdomain: $cidStr ($e)');
        response = Response.badRequest(body: 'Invalid CID');
      } catch (e, stackTrace) {
        _logger.error(
          'Error serving content for subdomain $cidStr',
          e,
          stackTrace,
        );
        response = Response.internalServerError(body: 'Internal server error');
      }
      _recordGatewayRequest(
        request.method,
        request.url.path,
        response.statusCode,
      );
      return response;
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

  /// Helper method to get a block by CID string.
  ///
  /// First tries the local blockstore, then falls back to Bitswap if a
  /// [bitswapHandler] is available and running.
  Future<Block?> _getBlockByCid(String cidStr) async {
    try {
      final response = await blockStore.getBlock(cidStr);
      if (response.found) {
        return Block.fromProto(response.block);
      }
    } catch (e, stackTrace) {
      _logger.error('Error getting block $cidStr', e, stackTrace);
    }

    final bitswap = bitswapHandler;
    if (bitswap != null) {
      try {
        _logger.debug('Attempting Bitswap retrieval for $cidStr');
        final networkBlock = await bitswap.wantBlock(cidStr);
        if (networkBlock != null) {
          // BitswapHandler stores received blocks in the blockstore; verify.
          final stored = await blockStore.getBlock(cidStr);
          if (stored.found) {
            return Block.fromProto(stored.block);
          }
          return networkBlock;
        }
      } catch (e, stackTrace) {
        _logger.warning('Bitswap retrieval failed for $cidStr', e, stackTrace);
      }
    }

    return null;
  }
}
