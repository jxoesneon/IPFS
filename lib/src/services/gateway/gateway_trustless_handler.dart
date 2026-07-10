// lib/src/services/gateway/gateway_trustless_handler.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart'
    show TrustlessFormat;
import 'package:shelf/shelf.dart';

import 'gateway_content_handler.dart';

/// Resolves IPNS record bytes for a given name.
typedef IpnsRecordResolver = Future<Uint8List?> Function(String name);

/// Handles trustless gateway response formats (raw, car, dag-json, dag-cbor,
/// ipns-record) and optional denylist checks.
class GatewayTrustlessHandler {
  /// Creates a trustless handler that delegates raw content handling to
  /// [contentHandler].
  GatewayTrustlessHandler({
    required this.contentHandler,
    this.ipnsRecordResolver,
    this.denylistService,
  });

  /// Handler used for raw/dag content retrieval.
  final GatewayContentHandler contentHandler;

  /// Optional resolver for IPNS record bytes.
  final IpnsRecordResolver? ipnsRecordResolver;

  /// Optional denylist service for blocking content.
  final DenylistService? denylistService;

  /// Detects the requested trustless response format from the request.
  TrustlessFormat? detectTrustlessFormat(Request request) {
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

  TrustlessFormat? _parseAcceptHeader(String accept) {
    const mediaTypeMap = {
      'application/vnd.ipfs.raw-block': TrustlessFormat.raw,
      'application/vnd.ipfs.car': TrustlessFormat.car,
      'application/vnd.ipfs.ipns-record': TrustlessFormat.ipnsRecord,
      'application/vnd.ipld.dag-json': TrustlessFormat.dagJson,
      'application/vnd.ipld.dag-cbor': TrustlessFormat.dagCbor,
    };

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

  /// Serves the raw block bytes for the requested CID.
  Future<Response> serveRawBlock(
    CID cid,
    Request request, {
    String? ipnsPath,
  }) async {
    final block = await contentHandler.blockStore.getBlock(cid.encode());
    if (!block.found) {
      return Response.notFound('Block not found');
    }

    final headers = {
      'content-type': 'application/vnd.ipfs.raw-block',
      'content-length': block.block.data.length.toString(),
      'x-ipfs-path': ipnsPath ?? '/ipfs/${cid.encode()}',
      'x-content-type-options': 'nosniff',
      'cache-control': 'public, max-age=29030400, immutable',
    };

    return Response.ok(block.block.data, headers: headers);
  }

  /// Serves the requested node as canonical DAG-JSON.
  Future<Response> serveDagJson(CID cid, Request request) async {
    final block = await contentHandler.blockStore.getBlock(cid.encode());
    if (!block.found) {
      return Response.notFound('Block not found');
    }

    final headers = {
      'content-type': 'application/vnd.ipld.dag-json',
      'content-length': block.block.data.length.toString(),
      'x-ipfs-path': '/ipfs/${cid.encode()}',
      'x-content-type-options': 'nosniff',
      'cache-control': 'public, max-age=29030400, immutable',
    };

    return Response.ok(block.block.data, headers: headers);
  }

  /// Serves the requested node as canonical DAG-CBOR.
  Future<Response> serveDagCbor(CID cid, Request request) async {
    final block = await contentHandler.blockStore.getBlock(cid.encode());
    if (!block.found) {
      return Response.notFound('Block not found');
    }

    final headers = {
      'content-type': 'application/vnd.ipld.dag-cbor',
      'content-length': block.block.data.length.toString(),
      'x-ipfs-path': '/ipfs/${cid.encode()}',
      'x-content-type-options': 'nosniff',
      'cache-control': 'public, max-age=29030400, immutable',
    };

    return Response.ok(block.block.data, headers: headers);
  }

  /// Serves the signed IPNS record bytes for the requested name.
  Future<Response> serveIpnsRecord(String name, Request request) async {
    if (ipnsRecordResolver == null) {
      return Response(501, body: 'IPNS record resolution disabled');
    }

    final recordBytes = await ipnsRecordResolver!(name);
    if (recordBytes == null || recordBytes.isEmpty) {
      return Response.notFound('IPNS record not found');
    }

    final headers = {
      'content-type': 'application/vnd.ipfs.ipns-record',
      'content-length': recordBytes.length.toString(),
      'x-ipfs-path': '/ipns/$name',
      'x-content-type-options': 'nosniff',
      'cache-control': 'public, max-age=60',
    };
    return Response.ok(recordBytes, headers: headers);
  }

  /// Dispatches a trustless format request to the appropriate handler.
  Future<Response> serveTrustless(
    CID cid,
    String subPath,
    TrustlessFormat format,
    Request request,
  ) async {
    switch (format) {
      case TrustlessFormat.raw:
        return serveRawBlock(cid, request);
      case TrustlessFormat.car:
        // Minimal CAR placeholder: return a single-block archive with the root.
        return Response.notFound('CAR not implemented');
      case TrustlessFormat.dagJson:
        return serveDagJson(cid, request);
      case TrustlessFormat.dagCbor:
        return serveDagCbor(cid, request);
      case TrustlessFormat.ipnsRecord:
        return Response(
          400,
          body: 'IPNS record format not supported for /ipfs/ paths',
        );
    }
  }

  /// Returns a 451 response if the CID or path is blocked by the denylist,
  /// or `null` if no denylist is configured or the content is not blocked.
  Response? checkDenylist(String pathOrCid) {
    final service = denylistService;
    if (service == null || !service.configuredEnabled) {
      return null;
    }
    if (!service.isBlockedByCidString(pathOrCid) &&
        !service.isBlockedPath(pathOrCid)) {
      return null;
    }
    return Response(
      451,
      body: 'Content blocked by operator policy',
      headers: {'content-type': 'text/plain'},
    );
  }
}
