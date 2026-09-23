// lib/src/services/gateway/gateway_handler.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/block/gated_block_fetcher.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/ipld_codec.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_hamt.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_reader.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:dart_ipfs/src/utils/dnslink_resolver.dart' as utils_dnslink;
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/utils/varint.dart';
import 'package:mime/mime.dart';
import 'package:multibase/multibase.dart';
import 'package:shelf/shelf.dart';

/// Resolver function for IPNS names (returns CID).
typedef IpnsResolver = Future<String> Function(String name);

/// Resolver function for IPNS record bytes (returns signed record bytes).
typedef IpnsRecordResolver = Future<Uint8List?> Function(String name);

/// Resolver function for DNSLink domains (returns a resolved IPFS/IPNS path).
typedef DnsLinkResolver = Future<DnsLinkResult?> Function(String domain);

/// Result of a DNSLink resolution.
class DnsLinkResult {
  /// Creates a DNSLink result with a resolved [path] and optional [ttlSeconds].
  DnsLinkResult(this.path, {this.ttlSeconds = 60});

  /// The resolved path, either `/ipfs/<cid>` or `/ipns/<name>`.
  final String path;

  /// The TTL in seconds to cache the result.
  final int ttlSeconds;
}

/// A request parsed from a subdomain-style gateway host.
class SubdomainRequest {
  /// Creates a subdomain request descriptor.
  SubdomainRequest(
    this.namespace,
    this.identifier,
    this.subPath,
    this.gatewayDomain,
  );

  /// The namespace, either `ipfs` or `ipns`.
  final String namespace;

  /// The identifier (CID for `ipfs`, PeerId/DNSLink/IPNS key for `ipns`).
  final String identifier;

  /// The remaining path inside the content root.
  final String subPath;

  /// The configured gateway domain that was matched.
  final String gatewayDomain;
}

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

/// Result of trustless format negotiation for a single request.
class _TrustlessNegotiation {
  _TrustlessNegotiation({
    this.format,
    this.formatFromQuery = false,
    this.acceptFormat,
    this.carAcceptParams = const {},
    this.error,
  });

  /// The negotiated trustless format, or `null` when the request did not
  /// ask for one (descriptive path-gateway handling applies).
  final TrustlessFormat? format;

  /// Whether the format came from the `?format=` query parameter.
  final bool formatFromQuery;

  /// The format negotiated from the `Accept` header, if any. Used to detect
  /// `format`/`Accept` mismatches for `Content-Location` reporting.
  final TrustlessFormat? acceptFormat;

  /// CAR content-type parameters (`version`, `order`, `dups`) negotiated via
  /// the `Accept` header entry that selected the CAR format.
  final Map<String, String> carAcceptParams;

  /// A ready-made error response (400/406) when negotiation failed.
  final Response? error;
}

/// The outcome of resolving an `ipns` subdomain identifier.
class _SubdomainIpnsResolution {
  _SubdomainIpnsResolution(this.cid, {this.dnsLinkDomain, this.ttlSeconds});

  /// The resolved content root CID string.
  final String cid;

  /// The DNS name that was resolved via DNSLink, if any.
  final String? dnsLinkDomain;

  /// The DNSLink TTL in seconds, when known.
  final int? ttlSeconds;
}

/// A single parsed `Accept` header entry.
class _AcceptEntry {
  _AcceptEntry(this.mediaType, this.q, this.params);

  /// The lowercased media type.
  final String mediaType;

  /// The parsed `q` weight (defaults to 1.0).
  final double q;

  /// Content-type parameters attached to this entry (excluding `q`).
  final Map<String, String> params;
}

/// Result of parsing an `Accept` header.
class _AcceptResult {
  _AcceptResult(this.format, this.carParams);

  /// The selected trustless format.
  final TrustlessFormat format;

  /// CAR content-type parameters, merged with `car-*` query overrides.
  final Map<String, String> carParams;
}

/// Mutable traversal state shared across a CAR generation walk.
class _CarTraversal {
  _CarTraversal({required this.dedup});

  /// Whether repeated CIDs are written only once (`dups=n`).
  final bool dedup;

  /// CIDs already emitted (populated only when [dedup] is true).
  final Set<String> seen = {};

  /// Total blocks written so far, regardless of dedup.
  int written = 0;

  /// Total payload bytes written so far, regardless of dedup.
  int bytesWritten = 0;
}

/// Thrown when a denylisted block is encountered while assembling a
/// response body (CAR stream, directory traversal, or reassembled file).
///
/// Extends [CarException] so CAR traversal loops that rethrow CAR errors
/// propagate it unchanged; handlers map it to a 451 response instead of
/// serving a response that contains denylisted content.
class _DenylistBlockedException extends CarException
    implements DenylistBlockedException {
  /// Creates a [_DenylistBlockedException] for the denylisted [cidStr].
  _DenylistBlockedException(this.cid) : super('Denylisted block: $cid');

  @override
  final String? cid;
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
    this.gatewayDomain,
    this.enableSubdomainGateway = false,
    this.subdomainDNSLinkResolver = true,
    this.subdomainTLSRedirect = false,
    this.dnsLinkResolver,
    this.trustForwardedHeaders = false,
    this.maxFileResponseBytes = unixfsReadDefaultMaxBytes,
    this.maxCarResponseBytes = _defaultMaxCarBytes,
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
  /// TODO: coordinate with the metrics module to add a dedicated
  /// `ipfs_gateway_requests_total` counter rather than reusing the generic
  /// protocol metrics stream.
  final MetricsCollector? metricsCollector;

  /// Configured gateway domain for subdomain requests (e.g. `ipfs.example.com`).
  final String? gatewayDomain;

  /// Whether subdomain gateway support is enabled.
  final bool enableSubdomainGateway;

  /// Whether DNSLink resolution is enabled for `.ipns` subdomains.
  final bool subdomainDNSLinkResolver;

  /// Whether HTTP subdomain requests should be redirected to HTTPS.
  final bool subdomainTLSRedirect;

  /// Optional resolver for DNSLink domains.
  final DnsLinkResolver? dnsLinkResolver;

  /// Whether `X-Forwarded-Host` / `X-Forwarded-Proto` headers are trusted.
  ///
  /// Defaults to `false`: these headers are trivially spoofable by direct
  /// clients, so honoring them unconditionally lets an attacker force open
  /// redirects to arbitrary hosts. Enable only when the gateway sits behind
  /// a trusted reverse proxy that strips and rewrites forwarded headers.
  final bool trustForwardedHeaders;

  /// Maximum number of bytes a single file response will buffer and serve.
  ///
  /// Bounds the memory a chunked UnixFS file can consume while being
  /// reassembled; responses that would exceed the budget are answered with
  /// HTTP 413.
  final int maxFileResponseBytes;

  /// Maximum total payload bytes a generated CAR archive may contain.
  ///
  /// The CAR writer buffers the archive in memory, so a byte bound (not just
  /// a block count) is required to keep a large DAG from consuming
  /// unbounded memory per request. Exceeding it fails the request with 416.
  final int maxCarResponseBytes;

  final _logger = Logger('GatewayHandler');

  /// The shared denylist-gated fetch pipeline backing [_getBlock] and
  /// [_getBlockByCid]: denylist gate first, then identity-CID synthesis,
  /// then the local block store, then Bitswap. The Bitswap handler already
  /// writes received blocks to the store, so the store is re-read after a
  /// network fetch instead of writing back here.
  late final GatedBlockFetcher _blockFetcher = GatedBlockFetcher(
    denylistGate: _throwIfDenylisted,
    localGet: _localGetBlock,
    wantBlock: _wantBlockBitswap,
    rereadAfterFetch: true,
  );

  /// Maximum number of `index.html` indirections followed while serving a
  /// directory. A directory whose `index.html` link resolves to another
  /// directory containing its own `index.html` would otherwise recurse
  /// indefinitely.
  static const int _maxIndexHtmlDepth = 8;

  /// Default limits for CAR traversal to prevent unbounded resource use.
  static const int _defaultMaxCarDepth = 32;
  static const int _defaultMaxCarBlocks = 10000;
  static const int _defaultMaxCarBytes = carExportDefaultMaxBytes;

  /// Default TTL for IPNS record Cache-Control when no record TTL is available.
  static const int _defaultIpnsTtlSeconds = 60;

  /// Returns a 451 response if the CID or path is blocked by the denylist.
  ///
  /// Returns `null` when the content is not blocked, no denylist is configured,
  /// or the configured policy is to log hits rather than block them.
  Response? _checkDenylist(String pathOrCid, {String source = 'gateway'}) {
    final service = denylistService;
    if (service == null || !service.configuredEnabled) {
      return null;
    }
    if (!service.isBlockedByCidString(pathOrCid) &&
        !service.isBlockedPath(pathOrCid)) {
      return null;
    }

    final action = service.recordHit(pathOrCid, source: source);
    if (action == 'log') {
      return null;
    }

    return _denylistBlockedResponse();
  }

  /// The shared 451 body for denylisted content.
  Response _denylistBlockedResponse() {
    return Response(
      451,
      body: 'Content blocked by operator policy',
      headers: {'Content-Type': 'text/plain'},
    );
  }

  /// Throws a [_DenylistBlockedException] when [cidStr] is denylisted and
  /// the configured default action is `block`.
  ///
  /// The hit is always recorded via [DenylistService.recordHit]; under the
  /// `log` action this returns normally after logging, matching
  /// [_checkDenylist] semantics. This gates blocks fetched mid-traversal —
  /// CAR children, path-resolution steps, and UnixFS file chunks — whose
  /// CIDs are not part of the request path checked by [_checkDenylist].
  void _throwIfDenylisted(String cidStr) {
    final service = denylistService;
    if (service == null || !service.configuredEnabled) {
      return;
    }
    if (!service.isBlockedByCidString(cidStr)) {
      return;
    }
    if (service.recordHit(cidStr, source: 'gateway') == 'block') {
      throw _DenylistBlockedException(cidStr);
    }
  }

  /// Records a gateway request metric if a [MetricsCollector] is available.
  ///
  /// This is intentionally a thin wrapper around the existing collector to
  /// avoid duplicating metrics implementation. A dedicated counter API should
  /// be added by the metrics module.
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

    // URI router (subdomain-gateway spec §4.4): `?uri=ipfs://…` overrides
    // regular path routing and is answered with a redirect to the equivalent
    // content path, so browsers can register `/ipfs/?uri=%s` as a protocol
    // handler.
    final uriParam = request.url.queryParameters['uri'];
    if (uriParam != null && uriParam.isNotEmpty) {
      response = _handleUriRouter(request, uriParam);
      _recordGatewayRequest(request.method, path, response.statusCode);
      return response;
    }

    // Parse IPFS path
    if (path.startsWith('ipfs/')) {
      final parts = path.substring(5).split('/');
      final cidStr = parts[0];
      final subPath = parts.length > 1 ? parts.sublist(1).join('/') : '';

      // Subdomain-gateway migration: when the subdomain gateway is enabled
      // and the Host does not carry the content root, valid content paths
      // are redirected to the equivalent subdomain URL.
      final migration = _subdomainMigrationRedirect(
        request,
        'ipfs',
        cidStr,
        subPath,
      );
      if (migration != null) {
        _recordGatewayRequest(request.method, path, migration.statusCode);
        return migration;
      }

      try {
        final denylisted = _checkDenylist(
          subPath.isEmpty ? '/ipfs/$cidStr' : '/ipfs/$cidStr/$subPath',
        );
        if (denylisted != null) {
          response = denylisted;
        } else {
          final cid = _decodeCid(cidStr);
          final negotiation = _negotiateTrustless(request);
          final negError = negotiation.error;
          if (negError != null) {
            response = negError;
          } else if (negotiation.format != null) {
            response = await _serveTrustless(
              cid,
              subPath,
              negotiation,
              request,
            );
          } else {
            response = await _serveContent(cidStr, subPath, request);
          }
        }
      } on FormatException catch (e) {
        _logger.warning('Invalid CID in path: $cidStr ($e)');
        response = Response.badRequest(body: 'Invalid CID');
      } on _DenylistBlockedException {
        // A denylisted child block was reached while traversing the DAG.
        response = _denylistBlockedResponse();
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

      final migration = _subdomainMigrationRedirect(
        request,
        'ipns',
        name,
        subPath,
      );
      if (migration != null) {
        _recordGatewayRequest(request.method, path, migration.statusCode);
        return migration;
      }

      try {
        final denylisted = _checkDenylist(
          subPath.isEmpty ? '/ipns/$name' : '/ipns/$name/$subPath',
        );
        if (denylisted != null) {
          response = denylisted;
        } else {
          final negotiation = _negotiateTrustless(request);
          final negError = negotiation.error;
          if (negError != null) {
            response = negError;
          } else if (negotiation.format == TrustlessFormat.ipnsRecord) {
            if (subPath.isNotEmpty) {
              // application/vnd.ipfs.ipns-record only applies to the IPNS
              // name itself; paths under it are a 400 per the spec.
              response = Response.badRequest(
                body: 'IPNS record requests do not support sub-paths',
              );
            } else {
              response = await _serveIpnsRecord(name, request, negotiation);
            }
          } else if (ipnsResolver == null) {
            response = Response(501, body: 'IPNS resolution disabled');
          } else {
            final cid = await ipnsResolver!(name);
            // The resolved CID must be checked too: an allowed IPNS name
            // must not become a proxy for denylisted content.
            final resolvedDenylisted = _checkDenylist(
              subPath.isEmpty ? '/ipfs/$cid' : '/ipfs/$cid/$subPath',
            );
            if (resolvedDenylisted != null) {
              response = resolvedDenylisted;
            } else if (negotiation.format != null) {
              response = await _serveTrustless(
                _decodeCid(cid),
                subPath,
                negotiation,
                request,
                ipnsPath: '/ipns/$name',
              );
            } else {
              response = await _serveContent(cid, subPath, request);
            }
          }
        }
      } on _DenylistBlockedException {
        // A denylisted child block was reached while traversing the DAG.
        response = _denylistBlockedResponse();
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

  /// Media type for raw block responses, per the trustless gateway spec.
  static const String mediaTypeRaw = 'application/vnd.ipld.raw';

  /// Media type for CAR stream responses, per the trustless gateway spec.
  static const String mediaTypeCar = 'application/vnd.ipld.car';

  /// Media type for signed IPNS record responses.
  static const String mediaTypeIpnsRecord = 'application/vnd.ipfs.ipns-record';

  /// Media type for DAG-JSON responses.
  static const String mediaTypeDagJson = 'application/vnd.ipld.dag-json';

  /// Media type for DAG-CBOR responses.
  static const String mediaTypeDagCbor = 'application/vnd.ipld.dag-cbor';

  /// Media types understood by `_parseAcceptHeader`.
  static const Map<String, TrustlessFormat> _mediaTypeFormats = {
    mediaTypeRaw: TrustlessFormat.raw,
    mediaTypeCar: TrustlessFormat.car,
    mediaTypeIpnsRecord: TrustlessFormat.ipnsRecord,
    mediaTypeDagJson: TrustlessFormat.dagJson,
    mediaTypeDagCbor: TrustlessFormat.dagCbor,
    // Legacy names emitted by earlier versions of this gateway; accepted for
    // inbound compatibility but never produced in responses.
    'application/vnd.ipfs.raw-block': TrustlessFormat.raw,
    'application/vnd.ipfs.car': TrustlessFormat.car,
  };

  /// `?format=` values that are valid path-gateway formats but not
  /// implemented by this gateway; they produce 406 rather than 400.
  static const _unsupportedPathGatewayFormats = {
    'tar',
    'json',
    'cbor',
    'fs',
    'application/x-tar',
    'application/json',
    'application/cbor',
  };

  /// Detects the requested trustless response format and negotiates
  /// content-type parameters for the request.
  ///
  /// `?format=` takes precedence over the `Accept` header, per the gateway
  /// spec. When `format` is `null` no trustless format was requested and the
  /// descriptive path gateway applies. When `error` is non-null the request
  /// must be rejected with that response (400/406) instead of silently
  /// falling back to a deserialized response.
  _TrustlessNegotiation _negotiateTrustless(Request request) {
    final formatParam = request.url.queryParameters['format'];
    final acceptResult = _parseAcceptHeader(request);

    if (formatParam != null && formatParam.isNotEmpty) {
      final format = _parseFormat(formatParam);
      if (format == null) {
        final known = _unsupportedPathGatewayFormats.contains(
          formatParam.toLowerCase(),
        );
        return _TrustlessNegotiation(
          error: Response(
            known ? 406 : 400,
            body: known
                ? 'Unsupported response format: $formatParam'
                : 'Invalid format: $formatParam',
            headers: const {'Content-Type': 'text/plain; charset=utf-8'},
          ),
        );
      }
      return _TrustlessNegotiation(
        format: format,
        formatFromQuery: true,
        acceptFormat: acceptResult?.format,
        carAcceptParams: acceptResult?.carParams ?? const {},
      );
    }

    if (acceptResult != null) {
      return _TrustlessNegotiation(
        format: acceptResult.format,
        carAcceptParams: acceptResult.carParams,
      );
    }
    return _TrustlessNegotiation();
  }

  /// Parses a `?format=` query value into a trustless format. Both the short
  /// spec aliases and the full media types are accepted.
  TrustlessFormat? _parseFormat(String value) {
    switch (value.toLowerCase()) {
      case 'raw':
      case mediaTypeRaw:
        return TrustlessFormat.raw;
      case 'car':
      case mediaTypeCar:
        return TrustlessFormat.car;
      case 'ipns-record':
      case mediaTypeIpnsRecord:
        return TrustlessFormat.ipnsRecord;
      case 'dag-json':
      case mediaTypeDagJson:
        return TrustlessFormat.dagJson;
      case 'dag-cbor':
      case mediaTypeDagCbor:
        return TrustlessFormat.dagCbor;
      default:
        return null;
    }
  }

  /// Parses the `Accept` header and returns the best supported trustless
  /// media type, or `null` if none is supported.
  ///
  /// Entries are honored in descending `q` order (RFC 9110 §12.5.1). CAR
  /// entries whose content-type parameters (`version`, `order`, `dups`) —
  /// after `car-*` query parameter overrides — cannot be satisfied are
  /// skipped in favor of lower-preference entries; if every acceptable CAR
  /// variant is unsatisfiable, the first one is still returned so the CAR
  /// handler can respond with a spec-compliant 406.
  _AcceptResult? _parseAcceptHeader(Request request) {
    final accept = request.headers['accept'];
    if (accept == null) return null;

    final entries = <_AcceptEntry>[];
    for (final rawEntry in accept.split(',')) {
      final parts = rawEntry.split(';');
      final type = parts.first.trim().toLowerCase();
      if (type.isEmpty) continue;
      var q = 1.0;
      final params = <String, String>{};
      for (final part in parts.skip(1)) {
        final kv = part.split('=');
        if (kv.length != 2) continue;
        final name = kv[0].trim().toLowerCase();
        final value = kv[1].trim().replaceAll('"', '');
        if (name == 'q') {
          q = double.tryParse(value) ?? 1.0;
        } else {
          params[name] = value;
        }
      }
      entries.add(_AcceptEntry(type, q, params));
    }

    // Sort by descending q, keeping header order for equal q values.
    final order = List<int>.generate(entries.length, (i) => i)
      ..sort((a, b) {
        final cmp = entries[b].q.compareTo(entries[a].q);
        return cmp != 0 ? cmp : a.compareTo(b);
      });

    _AcceptEntry? firstUnsatisfiableCar;
    for (final i in order) {
      final entry = entries[i];
      if (entry.q <= 0) continue;
      final format = _mediaTypeFormats[entry.mediaType];
      if (format == null) continue;
      if (format == TrustlessFormat.car) {
        final merged = _mergedCarParams(entry.params, request);
        if (_carParamsSatisfiable(merged)) {
          return _AcceptResult(format, merged);
        }
        firstUnsatisfiableCar ??= entry;
        continue;
      }
      return _AcceptResult(format, const {});
    }

    if (firstUnsatisfiableCar != null) {
      return _AcceptResult(
        TrustlessFormat.car,
        _mergedCarParams(firstUnsatisfiableCar.params, request),
      );
    }
    return null;
  }

  /// Merges CAR content-type parameters from an `Accept` entry with the
  /// `car-version`/`car-order`/`car-dups` query parameters, which take
  /// precedence per the spec.
  Map<String, String> _mergedCarParams(
    Map<String, String> acceptParams,
    Request request,
  ) {
    final merged = Map<String, String>.of(acceptParams);
    final qp = request.url.queryParameters;
    for (final key in const ['version', 'order', 'dups']) {
      final override = qp['car-$key'];
      if (override != null) merged[key] = override;
    }
    return merged;
  }

  /// Whether the given CAR content-type parameters describe a variant this
  /// gateway can produce (version 1, `dfs`/`unk` order, `y`/`n` dups).
  bool _carParamsSatisfiable(Map<String, String> params) {
    final version = params['version'];
    if (version != null && version.isNotEmpty && version != '1') {
      return false;
    }
    final order = params['order'];
    if (order != null &&
        order.isNotEmpty &&
        order != 'dfs' &&
        order != 'unk' &&
        order != 'unknown') {
      return false;
    }
    final dups = params['dups'];
    if (dups != null && dups.isNotEmpty && dups != 'y' && dups != 'n') {
      return false;
    }
    return true;
  }

  /// Dispatches a trustless format request to the appropriate handler.
  Future<Response> _serveTrustless(
    CID cid,
    String subPath,
    _TrustlessNegotiation negotiation,
    Request request, {
    String? ipnsPath,
  }) async {
    final denylistBase = ipnsPath ?? '/ipfs/${cid.encode()}';
    final denylisted = _checkDenylist(
      subPath.isEmpty ? denylistBase : '$denylistBase/$subPath',
    );
    if (denylisted != null) {
      return denylisted;
    }

    switch (negotiation.format!) {
      case TrustlessFormat.raw:
        return await _serveRawBlock(
          cid,
          request,
          ipnsPath: ipnsPath,
          negotiation: negotiation,
        );
      case TrustlessFormat.car:
        return await _serveCar(
          cid,
          subPath,
          request,
          ipnsPath: ipnsPath,
          negotiation: negotiation,
        );
      case TrustlessFormat.dagJson:
        return await _serveDagJson(
          cid,
          request,
          ipnsPath: ipnsPath,
          negotiation: negotiation,
        );
      case TrustlessFormat.dagCbor:
        return await _serveDagCbor(
          cid,
          request,
          ipnsPath: ipnsPath,
          negotiation: negotiation,
        );
      case TrustlessFormat.ipnsRecord:
        // ipns-record requests are only valid under the IPNS namespace, and
        // do not support sub-paths (per the path-gateway spec).
        return Response.badRequest(
          body: 'IPNS record format not supported for /ipfs/ paths',
        );
    }
  }

  /// Serves content for a given CID and optional sub-path
  ///
  /// [indexDepth] counts the `index.html` indirections followed so far; a
  /// directory whose `index.html` is itself a directory containing another
  /// `index.html` would otherwise recurse forever.
  Future<Response> _serveContent(
    String cidStr,
    String subPath,
    Request request, {
    int indexDepth = 0,
  }) async {
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
            // Kubo parity: directory requests must end with a trailing
            // slash; respond with a permanent redirect first. This only
            // applies to the resolved directory itself — a sub-path like
            // `/ipfs/<dir>/file.txt` resolves to a file and is served
            // without a redirect.
            final redirect = _directorySlashRedirect(request);
            if (redirect != null) {
              return redirect;
            }

            // Kubo parity: a directory containing index.html serves that
            // file transparently instead of the listing. The indirection is
            // capped so an index.html pointing at another directory with
            // its own index.html cannot recurse indefinitely.
            final indexLink = findLinkByName(pbNode.links, 'index.html');
            if (indexLink != null) {
              if (indexDepth >= _maxIndexHtmlDepth) {
                return Response.internalServerError(
                  body: 'index.html resolution depth exceeded',
                );
              }
              final indexCid = _decodeLinkCid(indexLink.hash);
              return await _serveContent(
                indexCid.encode(),
                '',
                request,
                indexDepth: indexDepth + 1,
              );
            }
            return _renderDirectory(cidStr, pbNode, request);
          } else {
            // Navigate to sub-path
            return await _navigateDirectory(
              cidStr,
              pbNode,
              subPath,
              request,
              indexDepth: indexDepth,
            );
          }
        }

        // Handle HAMT-sharded directories: the flat link scan used for
        // plain directories cannot resolve names inside a shard, so path
        // segments are resolved through the murmur3-bucketed links.
        if (unixfsData.type == Data_DataType.HAMTShard) {
          if (subPath.isEmpty) {
            final redirect = _directorySlashRedirect(request);
            if (redirect != null) {
              return redirect;
            }
          }
          return await _serveHamtShard(
            block,
            cidStr,
            subPath,
            request,
            indexDepth: indexDepth,
          );
        }

        // Handle files
        if (unixfsData.type == Data_DataType.File) {
          return await _serveFile(block, cidStr, request);
        }
      }
    } on _DenylistBlockedException {
      // A denylisted child block was reached during navigation or file
      // reassembly — never fall back to serving the raw block.
      rethrow;
    } on StateError catch (e) {
      // The block IS UnixFS but traversal failed mid-DAG: a linked block is
      // missing or a traversal budget was exceeded. Serving the raw PBNode
      // bytes under a 200 would masquerade as content, so report the
      // failure instead (Kubo answers 500/504 for missing blocks).
      _logger.warning('UnixFS traversal failed for $cidStr: $e');
      return Response.internalServerError(
        body: 'Failed to resolve content: ${e.message}',
      );
    } catch (e) {
      // Not UnixFS, serve as raw block
    }

    // Serve raw block
    return _serveRaw(block, cidStr, request);
  }

  /// Returns a 301 redirect appending a trailing slash when [request] does
  /// not already end with one, or `null` when no redirect is needed.
  ///
  /// The `Host` header is preferred over the request URI authority so that
  /// redirects issued on subdomain gateway requests keep the
  /// `{id}.{ipfs|ipns}.{gateway}` origin instead of collapsing to the
  /// listening address.
  Response? _directorySlashRedirect(Request request) {
    final uri = request.requestedUri;
    if (uri.path.endsWith('/')) {
      return null;
    }
    final host = request.headers['host'];
    final authority = (host != null && host.isNotEmpty) ? host : uri.authority;
    final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
    return Response.movedPermanently(
      '$scheme://$authority${uri.path}/'
      '${uri.hasQuery ? '?${uri.query}' : ''}',
    );
  }

  /// Serves a UnixFS file, reassembling chunked content from linked blocks.
  ///
  /// The reassembled payload is bounded by [maxFileResponseBytes]; files that
  /// would exceed the budget are answered with HTTP 413 rather than being
  /// buffered into memory in full.
  Future<Response> _serveFile(
    Block block,
    String cidStr,
    Request request,
  ) async {
    final Uint8List data;
    try {
      data = await unixfsReadFile(
        block,
        (cid) => _getBlockByCid(cid.encode()),
        maxBytes: maxFileResponseBytes,
      );
    } on StateError catch (e) {
      if (e.message.startsWith(unixfsReadByteBudgetExceededPrefix)) {
        return Response(
          413,
          body: 'File exceeds maximum response size',
          headers: const {'Content-Type': 'text/plain; charset=utf-8'},
        );
      }
      // Missing linked blocks and depth/node budget failures propagate to
      // _serveContent's StateError handler, which answers 500.
      rethrow;
    }
    final contentType = _detectContentType(data);

    final headers = {
      'Content-Type': contentType,
      'Content-Length': data.length.toString(),
      'X-IPFS-Path': '/ipfs/$cidStr',
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'public, max-age=29030400, immutable',
      'Etag': '"$cidStr"',
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
      'Etag': '"$cidStr"',
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

  /// Whether the request carries `Cache-Control: only-if-cached`, in which
  /// case trustless responses must come from the local block store only and
  /// a missing root block yields 412 Precondition Failed.
  bool _requestsOnlyIfCached(Request request) {
    final cc = request.headers['cache-control'];
    if (cc == null) return false;
    return cc
        .toLowerCase()
        .split(',')
        .map((e) => e.trim())
        .contains('only-if-cached');
  }

  /// Headers shared by every negotiated trustless response.
  Map<String, String> _trustlessHeaders({
    required String contentType,
    required int contentLength,
    required String path,
    required String etag,
    String? contentDisposition,
    String? contentLocation,
    String cacheControl = 'public, max-age=29030400, immutable',
  }) {
    return {
      'Content-Type': contentType,
      'Content-Length': contentLength.toString(),
      'X-IPFS-Path': path,
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': cacheControl,
      'Etag': etag,
      'Vary': 'Accept',
      'Content-Disposition': ?contentDisposition,
      'Content-Location': ?contentLocation,
    };
  }

  /// Short `?format=` name for a trustless format.
  String _formatName(TrustlessFormat format) {
    switch (format) {
      case TrustlessFormat.raw:
        return 'raw';
      case TrustlessFormat.car:
        return 'car';
      case TrustlessFormat.ipnsRecord:
        return 'ipns-record';
      case TrustlessFormat.dagJson:
        return 'dag-json';
      case TrustlessFormat.dagCbor:
        return 'dag-cbor';
    }
  }

  /// Per the path-gateway spec, `Content-Location` should be returned when a
  /// non-default format was negotiated — when `format` was absent from the
  /// URL or disagrees with the `Accept` header — so caches can key the
  /// response separately. We return it for every negotiated response.
  String? _contentLocation(Request request, _TrustlessNegotiation neg) {
    final format = neg.format;
    if (format == null) return null;
    final uri = request.requestedUri;
    final params = Map<String, String>.of(uri.queryParameters);
    params['format'] = _formatName(format);
    return Uri(path: uri.path, queryParameters: params).toString();
  }

  /// Builds an RFC 6266 `Content-Disposition` value for a binary download.
  ///
  /// The spec mandates `attachment` for raw block and CAR responses so that
  /// browsers never render the bytes. A `?filename=` query parameter may
  /// override the default filename; non-ASCII names get both an ASCII-safe
  /// `filename` and an RFC 8187 `filename*` parameter.
  String _contentDisposition(Request request, String defaultFilename) {
    final requested = request.url.queryParameters['filename'];
    final filename = (requested != null && requested.isNotEmpty)
        ? requested
        : defaultFilename;
    final ascii = filename
        .replaceAll('\\', '_')
        .replaceAll('"', '_')
        .replaceAll(RegExp(r'[^\x20-\x7e]'), '_');
    if (ascii == filename) {
      return 'attachment; filename="$ascii"';
    }
    final encoded = Uri.encodeComponent(filename);
    return "attachment; filename=\"$ascii\"; filename*=UTF-8''$encoded";
  }

  /// Serves the raw block bytes for the requested CID.
  Future<Response> _serveRawBlock(
    CID cid,
    Request request, {
    String? ipnsPath,
    required _TrustlessNegotiation negotiation,
  }) async {
    final localOnly = _requestsOnlyIfCached(request);
    final block = await _getBlock(cid, localOnly: localOnly);
    if (block == null) {
      if (localOnly) {
        return Response(
          412,
          body: 'Requested block is not available locally',
          headers: const {'Content-Type': 'text/plain; charset=utf-8'},
        );
      }
      return Response.notFound('Block not found');
    }

    final cidStr = cid.encode();
    final headers = _trustlessHeaders(
      contentType: mediaTypeRaw,
      contentLength: block.data.length,
      path: ipnsPath ?? '/ipfs/$cidStr',
      etag: '"$cidStr.raw"',
      contentDisposition: _contentDisposition(request, '$cidStr.bin'),
      contentLocation: _contentLocation(request, negotiation),
    );

    return Response.ok(block.data, headers: headers);
  }

  /// Serves a CAR v1 archive containing the requested CID and the DAG
  /// selected by `dag-scope`/`entity-bytes`, honoring `car-order`,
  /// `car-dups` and `car-version` negotiation.
  Future<Response> _serveCar(
    CID cid,
    String subPath,
    Request request, {
    String? ipnsPath,
    required _TrustlessNegotiation negotiation,
  }) async {
    const plainText = {'Content-Type': 'text/plain; charset=utf-8'};
    final localOnly = _requestsOnlyIfCached(request);

    // CAR content-type parameters: `car-*` query parameters take precedence
    // over `Accept` entry parameters (per IPIP-0412 / the trustless spec).
    final carParams = _mergedCarParams(negotiation.carAcceptParams, request);

    final versionParam = carParams['version'];
    if (versionParam != null &&
        versionParam.isNotEmpty &&
        versionParam != '1') {
      return Response(
        406,
        body: 'Unsupported CAR version: $versionParam',
        headers: plainText,
      );
    }
    final orderParam = carParams['order'];
    if (orderParam != null &&
        orderParam.isNotEmpty &&
        orderParam != 'dfs' &&
        orderParam != 'unk' &&
        orderParam != 'unknown') {
      return Response(
        406,
        body: 'Unsupported CAR order: $orderParam',
        headers: plainText,
      );
    }
    final dupsParam = carParams['dups'];
    final bool sendDuplicates;
    if (dupsParam == null || dupsParam.isEmpty || dupsParam == 'n') {
      sendDuplicates = false;
    } else if (dupsParam == 'y') {
      sendDuplicates = true;
    } else {
      return Response(
        400,
        body: 'Invalid CAR dups value: $dupsParam',
        headers: plainText,
      );
    }

    final qp = request.url.queryParameters;
    var dagScope = qp['dag-scope'] ?? 'all';
    if (dagScope != 'block' && dagScope != 'entity' && dagScope != 'all') {
      return Response(
        400,
        body: 'Invalid dag-scope value: $dagScope',
        headers: plainText,
      );
    }

    // `entity-bytes` implies dag-scope=entity.
    (int, int?)? entityBytes;
    final entityBytesParam = qp['entity-bytes'];
    if (entityBytesParam != null) {
      final parsed = _parseEntityBytes(entityBytesParam);
      if (parsed == null) {
        return Response(
          400,
          body: 'Invalid entity-bytes value: $entityBytesParam',
          headers: plainText,
        );
      }
      entityBytes = parsed;
      dagScope = 'entity';
    }

    // The root block must exist before we commit to a response: 404 (or 412
    // for only-if-cached requests) rather than a partial CAR.
    final rootBlock = await _getBlock(cid, localOnly: localOnly);
    if (rootBlock == null) {
      if (localOnly) {
        return Response(
          412,
          body: 'Requested block is not available locally',
          headers: plainText,
        );
      }
      return Response.notFound('Block not found');
    }

    // Resolve the sub-path, keeping every traversed block so the CAR
    // includes the blocks required to verify each path segment.
    final pathBlocks = await _resolvePathBlocks(
      cid,
      rootBlock,
      subPath,
      localOnly: localOnly,
    );
    if (pathBlocks == null) {
      return Response.notFound('Path not found');
    }
    final targetCid = pathBlocks.last.$1;
    final targetBlock = pathBlocks.last.$2;
    final baseDepth = pathBlocks.length - 1;

    // Resolve entity-bytes against the terminating entity when it is a
    // UnixFS file with a known size; the parameter is ignored for entities
    // that are not byte-addressable (equivalent to dag-scope=entity).
    (int, int)? entityRange;
    if (entityBytes != null) {
      final fileSize = _unixfsFileSize(targetBlock);
      if (fileSize != null) {
        final resolved = _resolveEntityRange(
          fileSize,
          entityBytes.$1,
          entityBytes.$2,
        );
        if (resolved == null) {
          return Response(
            400,
            body: 'entity-bytes range is entirely outside the entity',
            headers: plainText,
          );
        }
        entityRange = resolved;
      }
    }

    // An identity root carries its data inline; the CAR still advertises the
    // root in the header but the data section stays empty, since identity
    // blocks MUST NOT appear in CAR responses.
    if (cid.multihash.code == 0x00) {
      final carBytes = _carBytesForIdentityRoot(cid);
      final cidStr = cid.encode();
      final headers = _trustlessHeaders(
        contentType:
            '$mediaTypeCar; version=1; order=dfs; dups=${sendDuplicates ? 'y' : 'n'}',
        contentLength: carBytes.length,
        path: ipnsPath ?? '/ipfs/$cidStr',
        etag: '"$dagScope.$cidStr.car"',
        contentDisposition: _contentDisposition(request, '$cidStr.car'),
        contentLocation: _contentLocation(request, negotiation),
      );
      return Response.ok(carBytes, headers: headers);
    }

    final writer = CarWriter(roots: [cid]);
    final state = _CarTraversal(dedup: !sendDuplicates);

    try {
      // Path-verification blocks come first (DFS order: root → terminus).
      for (var i = 0; i < baseDepth; i++) {
        if (i > _defaultMaxCarDepth) {
          throw CarException(
            'CAR traversal exceeded maximum depth $_defaultMaxCarDepth',
          );
        }
        await _carWrite(pathBlocks[i].$1, pathBlocks[i].$2, writer, state);
      }

      switch (dagScope) {
        case 'block':
          await _carWrite(targetCid, targetBlock, writer, state);
        case 'entity':
          if (entityRange != null) {
            await _writeCarEntityRange(
              targetCid,
              targetBlock,
              writer,
              state,
              depth: baseDepth,
              rangeFrom: entityRange.$1,
              rangeTo: entityRange.$2,
              baseOffset: 0,
              localOnly: localOnly,
            );
          } else {
            await _writeCarEntity(
              targetCid,
              targetBlock,
              writer,
              state,
              depth: baseDepth,
              localOnly: localOnly,
            );
          }
        default: // 'all'
          await _writeCarSubtree(
            targetCid,
            targetBlock,
            writer,
            state,
            depth: baseDepth,
            localOnly: localOnly,
          );
      }

      final carBytes = await writer.close();
      final cidStr = cid.encode();
      final scopeTag = entityRange != null
          ? 'entity.${entityRange.$1}-${entityRange.$2}'
          : dagScope;
      final headers = _trustlessHeaders(
        contentType:
            '$mediaTypeCar; version=1; order=dfs; dups=${sendDuplicates ? 'y' : 'n'}',
        contentLength: carBytes.length,
        path: ipnsPath ?? '/ipfs/$cidStr',
        etag: '"$scopeTag.$cidStr.car"',
        contentDisposition: _contentDisposition(request, '$cidStr.car'),
        contentLocation: _contentLocation(request, negotiation),
      );
      return Response.ok(carBytes, headers: headers);
    } on _DenylistBlockedException {
      // A denylisted child block was reached during CAR traversal; the
      // archive must not be served at all rather than truncated.
      return _denylistBlockedResponse();
    } on CarException catch (e) {
      _logger.warning('CAR generation failed for ${cid.encode()}: $e');
      return Response(416, body: 'CAR generation failed: $e');
    } catch (e, stackTrace) {
      _logger.error('Error generating CAR for ${cid.encode()}', e, stackTrace);
      return Response.internalServerError(body: 'Internal server error');
    }
  }

  /// Builds a CAR v1 whose header declares [cid] as the only root with an
  /// empty data section — used for identity roots such as the `bafkqaaa`
  /// probe CID, whose bytes are already inline in the CID itself.
  ///
  /// The header is the fixed canonical DAG-CBOR map `{roots: [<cid>],
  /// version: 1}`. It is emitted byte-for-byte here because the DAG-CBOR
  /// codec cannot re-decode the zero-length identity multihash that a CIDv1
  /// like `bafkqaaa` carries.
  Uint8List _carBytesForIdentityRoot(CID cid) {
    // Tag 42 link value: 0x00 multibase prefix followed by the CID bytes.
    final taggedCid = Uint8List.fromList([0x00, ...cid.toBytes()]);
    final header = BytesBuilder()
      ..addByte(0xa2) // map of 2 pairs ("roots" sorts before "version")
      ..addByte(0x65) // text(5)
      ..add('roots'.codeUnits)
      ..addByte(0x81) // array(1)
      ..addByte(0xd8) // tag…
      ..addByte(0x2a) // …42 (CID link)
      ..add(_cborByteStringHeader(taggedCid.length))
      ..add(taggedCid)
      ..addByte(0x67) // text(7)
      ..add('version'.codeUnits)
      ..addByte(0x01); // uint 1
    final headerBytes = header.toBytes();
    return Uint8List.fromList([
      ...encodeVarint(headerBytes.length),
      ...headerBytes,
    ]);
  }

  /// CBOR major-type-2 (byte string) header for [length].
  Uint8List _cborByteStringHeader(int length) {
    if (length < 24) return Uint8List.fromList([0x40 + length]);
    if (length < 256) return Uint8List.fromList([0x58, length]);
    return Uint8List.fromList([0x59, length >> 8, length & 0xff]);
  }

  /// Writes a single section to the CAR, honoring dedup (`dups=n`), block
  /// limits, and the spec requirement that identity CIDs (multihash code
  /// `0x00`) never appear in CAR data sections.
  ///
  /// Returns `true` when a section was actually written.
  Future<bool> _carWrite(
    CID cid,
    Block block,
    CarWriter writer,
    _CarTraversal state,
  ) async {
    if (cid.multihash.code == 0x00) {
      _recordCarDenylistHit(cid);
      return false;
    }
    if (state.dedup && !state.seen.add(cid.encode())) {
      return false;
    }
    state.written++;
    if (state.written > _defaultMaxCarBlocks) {
      throw CarException(
        'CAR traversal exceeded maximum block count $_defaultMaxCarBlocks',
      );
    }
    state.bytesWritten += block.data.length;
    if (state.bytesWritten > maxCarResponseBytes) {
      throw CarException(
        'CAR traversal exceeded maximum byte budget $maxCarResponseBytes',
      );
    }
    await writer.write(cid, block.data);
    return true;
  }

  /// Records a denylist hit for an identity-CID link skipped during CAR
  /// traversal. Identity children are never fetched or written, so the
  /// per-block denylist gate in [_getBlock] never sees them — without this
  /// the audit trail would miss a blocked CID reached mid-traversal.
  void _recordCarDenylistHit(CID cid) {
    final service = denylistService;
    if (service == null || !service.configuredEnabled) {
      return;
    }
    final cidStr = cid.encode();
    if (service.isBlockedByCidString(cidStr)) {
      service.recordHit(cidStr, source: 'car');
    }
  }

  /// Decodes a DAG-PB link target, tolerating the zero-length identity
  /// multihash that [CID.fromBytes] rejects. Malformed targets surface the
  /// strict decoder's error.
  CID _decodeLinkCid(List<int> hash) {
    return tryDecodeCidBytesLenient(hash) ??
        CID.fromBytes(Uint8List.fromList(hash));
  }

  /// Fetches a linked block for CAR traversal, throwing on missing blocks.
  Future<Block> _carChildBlock(CID cid, {required bool localOnly}) async {
    final childBlock = await _getBlock(cid, localOnly: localOnly);
    if (childBlock == null) {
      // _getBlock already attempts Bitswap retrieval when available.
      throw CarException(
        'Missing linked block ${cid.encode()} during CAR traversal',
      );
    }
    return childBlock;
  }

  /// Recursively writes a node and its entire reachable DAG (`dag-scope=all`)
  /// into a CAR writer, in depth-first order.
  Future<void> _writeCarSubtree(
    CID cid,
    Block block,
    CarWriter writer,
    _CarTraversal state, {
    required int depth,
    bool localOnly = false,
  }) async {
    if (depth > _defaultMaxCarDepth) {
      throw CarException(
        'CAR traversal exceeded maximum depth $_defaultMaxCarDepth',
      );
    }
    final wrote = await _carWrite(cid, block, writer, state);
    if (state.dedup && !wrote) {
      return;
    }

    // Only DAG-PB nodes have navigable links for the full DAG traversal.
    if (block.cid.codec != 'dag-pb') {
      return;
    }

    try {
      final pbNode = PBNode.fromBuffer(block.data);
      for (final link in pbNode.links) {
        final linkCid = _decodeLinkCid(link.hash);
        if (linkCid.multihash.code == 0x00) {
          // identity CID: data is inline in the link
          _recordCarDenylistHit(linkCid);
          continue;
        }
        final childBlock = await _carChildBlock(linkCid, localOnly: localOnly);
        await _writeCarSubtree(
          linkCid,
          childBlock,
          writer,
          state,
          depth: depth + 1,
          localOnly: localOnly,
        );
      }
    } catch (e) {
      // If we cannot parse the node as DAG-PB, we already wrote the block as
      // a single section and stop recursion.
      if (e is CarException) rethrow;
    }
  }

  /// Writes the blocks that make up the entity rooted at [cid]
  /// (`dag-scope=entity`): every chunk of a UnixFS file, every shard block
  /// of a HAMT-sharded UnixFS directory, or just the block itself for any
  /// other node.
  Future<void> _writeCarEntity(
    CID cid,
    Block block,
    CarWriter writer,
    _CarTraversal state, {
    required int depth,
    bool localOnly = false,
  }) async {
    if (depth > _defaultMaxCarDepth) {
      throw CarException(
        'CAR traversal exceeded maximum depth $_defaultMaxCarDepth',
      );
    }
    final wrote = await _carWrite(cid, block, writer, state);
    if (state.dedup && !wrote) {
      return;
    }

    final links = await _entityChildLinks(block);
    for (final link in links) {
      final linkCid = _decodeLinkCid(link.hash);
      if (linkCid.multihash.code == 0x00) {
        _recordCarDenylistHit(linkCid);
        continue;
      }
      final childBlock = await _carChildBlock(linkCid, localOnly: localOnly);
      await _writeCarEntity(
        linkCid,
        childBlock,
        writer,
        state,
        depth: depth + 1,
        localOnly: localOnly,
      );
    }
  }

  /// Writes only the blocks needed to verify the byte range
  /// `[rangeFrom, rangeTo]` of the UnixFS file entity rooted at [cid]
  /// (`entity-bytes` implies `dag-scope=entity`). If the node is not a
  /// UnixFS file, falls back to entity semantics for its children.
  Future<void> _writeCarEntityRange(
    CID cid,
    Block block,
    CarWriter writer,
    _CarTraversal state, {
    required int depth,
    required int rangeFrom,
    required int rangeTo,
    required int baseOffset,
    bool localOnly = false,
  }) async {
    if (depth > _defaultMaxCarDepth) {
      throw CarException(
        'CAR traversal exceeded maximum depth $_defaultMaxCarDepth',
      );
    }
    final wrote = await _carWrite(cid, block, writer, state);
    if (state.dedup && !wrote) {
      return;
    }
    // A zero-length resolved range is equivalent to dag-scope=block.
    if (rangeFrom > rangeTo) {
      return;
    }
    if (block.cid.codec != 'dag-pb') {
      return;
    }

    PBNode pbNode;
    Data? unixfsData;
    try {
      pbNode = PBNode.fromBuffer(block.data);
      unixfsData = pbNode.hasData() ? Data.fromBuffer(pbNode.data) : null;
    } catch (_) {
      return;
    }
    if (unixfsData == null) {
      return;
    }

    if (unixfsData.type != Data_DataType.File) {
      // Not byte-addressable: entity-bytes degrades to dag-scope=entity.
      final links = _entityLinksFrom(pbNode, unixfsData);
      for (final link in links) {
        final linkCid = _decodeLinkCid(link.hash);
        if (linkCid.multihash.code == 0x00) {
          _recordCarDenylistHit(linkCid);
          continue;
        }
        final childBlock = await _carChildBlock(linkCid, localOnly: localOnly);
        await _writeCarEntity(
          linkCid,
          childBlock,
          writer,
          state,
          depth: depth + 1,
          localOnly: localOnly,
        );
      }
      return;
    }

    // UnixFS file node: its own inline `data` bytes occupy the start of the
    // node range, then `blocksizes[i]` gives the file bytes under link i.
    final blockSizes = unixfsData.blocksizes;
    if (blockSizes.length != pbNode.links.length) {
      // blocksizes missing/unreliable: include the whole file entity.
      for (final link in pbNode.links) {
        final linkCid = _decodeLinkCid(link.hash);
        if (linkCid.multihash.code == 0x00) {
          _recordCarDenylistHit(linkCid);
          continue;
        }
        final childBlock = await _carChildBlock(linkCid, localOnly: localOnly);
        await _writeCarEntity(
          linkCid,
          childBlock,
          writer,
          state,
          depth: depth + 1,
          localOnly: localOnly,
        );
      }
      return;
    }

    var cursor = baseOffset + unixfsData.data.length;
    for (var i = 0; i < pbNode.links.length; i++) {
      final link = pbNode.links[i];
      final childSize = blockSizes[i].toInt();
      final childStart = cursor;
      final childEnd = cursor + childSize - 1;
      cursor += childSize;

      final linkCid = _decodeLinkCid(link.hash);
      if (linkCid.multihash.code == 0x00) {
        _recordCarDenylistHit(linkCid);
        continue;
      }
      if (childSize <= 0) continue;
      if (childEnd < rangeFrom || childStart > rangeTo) continue;

      final childBlock = await _carChildBlock(linkCid, localOnly: localOnly);
      await _writeCarEntityRange(
        linkCid,
        childBlock,
        writer,
        state,
        depth: depth + 1,
        rangeFrom: rangeFrom,
        rangeTo: rangeTo,
        baseOffset: childStart,
        localOnly: localOnly,
      );
    }
  }

  /// Returns the links that belong to the entity itself for
  /// `dag-scope=entity`: all links of a UnixFS file (its chunks), sub-shard
  /// links of a HAMT-sharded directory (needed to enumerate it), or no links
  /// for any other node kind.
  Future<List<PBLink>> _entityChildLinks(Block block) async {
    if (block.cid.codec != 'dag-pb') {
      return const [];
    }
    try {
      final pbNode = PBNode.fromBuffer(block.data);
      final unixfsData = pbNode.hasData() ? Data.fromBuffer(pbNode.data) : null;
      if (unixfsData == null) {
        return const [];
      }
      return _entityLinksFrom(pbNode, unixfsData);
    } catch (_) {
      return const [];
    }
  }

  /// Entity-child selection on an already-parsed node.
  List<PBLink> _entityLinksFrom(PBNode pbNode, Data unixfsData) {
    switch (unixfsData.type) {
      case Data_DataType.File:
        // Every link of a UnixFS file node is part of the file entity.
        return pbNode.links;
      case Data_DataType.HAMTShard:
        // Enumerating a HAMT-sharded directory requires its sub-shard
        // blocks; entry links are not part of the directory entity.
        final width = _hamtPrefixWidth(unixfsData.fanout.toInt());
        return pbNode.links
            .where((l) => l.name.length == width)
            .toList(growable: false);
      default:
        return const [];
    }
  }

  /// Width in hex characters of a HAMT sub-shard link name for the given
  /// UnixFS fanout (256 → 2).
  int _hamtPrefixWidth(int fanout) {
    var f = fanout > 0 ? fanout : 256;
    var bits = 0;
    while (f > 1) {
      f >>= 1;
      bits++;
    }
    return bits ~/ 4;
  }

  /// Total file size of a UnixFS file block, or `null` when the block is not
  /// a byte-addressable UnixFS file entity.
  int? _unixfsFileSize(Block block) {
    if (block.cid.codec != 'dag-pb') {
      return null;
    }
    try {
      final pbNode = PBNode.fromBuffer(block.data);
      if (!pbNode.hasData()) return null;
      final data = Data.fromBuffer(pbNode.data);
      if (data.type != Data_DataType.File) return null;
      if (data.hasFilesize()) {
        return data.filesize.toInt();
      }
      // filesize omitted: it is the node's own data plus child block sizes.
      var total = data.data.length;
      for (final s in data.blocksizes) {
        total += s.toInt();
      }
      return total;
    } catch (_) {
      return null;
    }
  }

  /// Parses an `entity-bytes=from:to` value. `to` may be `*` (end of file,
  /// returned as `null`); both sides may be negative (from end of file).
  (int, int?)? _parseEntityBytes(String value) {
    final sep = value.indexOf(':');
    if (sep <= 0 || sep != value.lastIndexOf(':')) {
      return null;
    }
    final from = int.tryParse(value.substring(0, sep));
    final toPart = value.substring(sep + 1);
    if (from == null) return null;
    if (toPart == '*') return (from, null);
    final to = int.tryParse(toPart);
    if (to == null) return null;
    return (from, to);
  }

  /// Resolves a parsed `entity-bytes` range against a known entity size.
  ///
  /// Returns `null` when the range starts entirely past the end of the
  /// entity (the caller responds 400 since this is knowable upfront).
  /// A range that resolves to zero bytes is returned as `(from > to)` and
  /// degrades to `dag-scope=block` during traversal, per the spec.
  (int, int)? _resolveEntityRange(int fileSize, int from, int? to) {
    if (fileSize <= 0) {
      // An empty entity has no byte range; any request is zero-length.
      return (0, -1);
    }
    var start = from < 0 ? fileSize + from : from;
    var end = to == null ? fileSize - 1 : (to < 0 ? fileSize + to : to);
    if (start < 0) start = 0;
    if (start >= fileSize) return null;
    if (end >= fileSize) end = fileSize - 1;
    return (start, end);
  }

  /// Serves the signed IPNS record bytes for the requested name.
  ///
  /// The `application/vnd.ipfs.ipns-record` media type requires the wire
  /// `IpnsEntry` protobuf, so whatever encoding the resolver produced
  /// (the internal CBOR form or already-serialized `IpnsEntry` bytes) is
  /// normalized through [IPNSRecord.decode] and re-encoded with
  /// [IPNSRecord.toIpnsEntry].
  Future<Response> _serveIpnsRecord(
    String name,
    Request request,
    _TrustlessNegotiation negotiation,
  ) async {
    if (ipnsRecordResolver == null) {
      return Response(501, body: 'IPNS record resolution disabled');
    }

    final recordBytes = await ipnsRecordResolver!(name);
    if (recordBytes == null || recordBytes.isEmpty) {
      return Response.notFound('IPNS record not found');
    }

    final IPNSRecord record;
    final Uint8List entryBytes;
    try {
      record = IPNSRecord.decode(recordBytes, name: name);
      entryBytes = record.toIpnsEntry();
    } catch (e, stackTrace) {
      _logger.warning('Invalid IPNS record for $name', e, stackTrace);
      return Response.internalServerError(body: 'Invalid IPNS record');
    }

    final maxAge = record.ttl.inSeconds > 0
        ? record.ttl.inSeconds
        : _defaultIpnsTtlSeconds;
    // IPNS records are mutable — the Etag is a weak validator derived from
    // the record bytes rather than the name.
    final etag = 'W/"${sha256.convert(entryBytes).toString()}"';
    final headers = _trustlessHeaders(
      contentType: mediaTypeIpnsRecord,
      contentLength: entryBytes.length,
      path: '/ipns/$name',
      etag: etag,
      contentDisposition: _contentDisposition(request, '$name.ipns-record'),
      contentLocation: _contentLocation(request, negotiation),
      cacheControl: 'public, max-age=$maxAge',
    );
    return Response.ok(entryBytes, headers: headers);
  }

  /// IPLD codec registry used to decode stored blocks into the canonical
  /// [IPLDNode] representation before re-encoding to the negotiated
  /// response codec. Registered codecs own all encode/decode logic; the
  /// gateway never hand-encodes IPLD data.
  static final Map<String, IPLDCodec> _ipldCodecRegistry = {
    for (final codec in <IPLDCodec>[
      RawCodec(),
      DagPbCodec(),
      DagCborCodec(),
      DagJsonCodec(),
    ])
      codec.name: codec,
  };

  /// Serves the requested node as canonical DAG-JSON.
  Future<Response> _serveDagJson(
    CID cid,
    Request request, {
    String? ipnsPath,
    required _TrustlessNegotiation negotiation,
  }) async {
    final localOnly = _requestsOnlyIfCached(request);
    final block = await _getBlock(cid, localOnly: localOnly);
    if (block == null) {
      if (localOnly) {
        return _notLocallyAvailable();
      }
      return Response.notFound('Block not found');
    }

    try {
      // When the block is already DAG-JSON the bytes are returned verbatim —
      // verifiable against the CID — otherwise the codec registry transcodes.
      final encoded = block.cid.codec == 'dag-json'
          ? block.data
          : await DagJsonCodec().encode(await _decodeBlockAsIpldNode(block));
      final cidStr = cid.encode();
      final headers = _trustlessHeaders(
        contentType: mediaTypeDagJson,
        contentLength: encoded.length,
        path: ipnsPath ?? '/ipfs/$cidStr',
        etag: '"$cidStr.dag.json"',
        contentDisposition: _contentDisposition(request, '$cidStr.json'),
        contentLocation: _contentLocation(request, negotiation),
      );
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
    required _TrustlessNegotiation negotiation,
  }) async {
    final localOnly = _requestsOnlyIfCached(request);
    final block = await _getBlock(cid, localOnly: localOnly);
    if (block == null) {
      if (localOnly) {
        return _notLocallyAvailable();
      }
      return Response.notFound('Block not found');
    }

    try {
      final encoded = block.cid.codec == 'dag-cbor'
          ? block.data
          : await DagCborCodec().encode(await _decodeBlockAsIpldNode(block));
      final cidStr = cid.encode();
      final headers = _trustlessHeaders(
        contentType: mediaTypeDagCbor,
        contentLength: encoded.length,
        path: ipnsPath ?? '/ipfs/$cidStr',
        etag: '"$cidStr.dag.cbor"',
        contentDisposition: _contentDisposition(request, '$cidStr.cbor'),
        contentLocation: _contentLocation(request, negotiation),
      );
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

  /// 412 response for `Cache-Control: only-if-cached` requests whose root
  /// block is not in the local block store.
  Response _notLocallyAvailable() {
    return Response(
      412,
      body: 'Requested block is not available locally',
      headers: const {'Content-Type': 'text/plain; charset=utf-8'},
    );
  }

  /// Decodes a block into the canonical IPLD node representation for the codec.
  Future<IPLDNode> _decodeBlockAsIpldNode(Block block) async {
    final codec = _ipldCodecRegistry[block.cid.codec];
    if (codec == null) {
      // For unknown codecs, try to interpret as raw bytes; this preserves
      // deterministic responses while avoiding arbitrary failures.
      return await _ipldCodecRegistry['raw']!.decode(block.data);
    }
    return await codec.decode(block.data);
  }

  /// Resolves [subPath] from the root and returns the ordered `(cid, block)`
  /// pairs of every block traversed, from the root to the resolved terminus
  /// (inclusive). Returns `null` when a path segment does not resolve or a
  /// required block is missing.
  Future<List<(CID, Block)>?> _resolvePathBlocks(
    CID rootCid,
    Block rootBlock,
    String subPath, {
    bool localOnly = false,
  }) async {
    final blocks = <(CID, Block)>[(rootCid, rootBlock)];
    final parts = subPath.split('/').where((p) => p.isNotEmpty).toList();

    for (final part in parts) {
      final next = await _findChildCid(blocks.last.$2, part);
      if (next == null) {
        return null;
      }
      final nextBlock = await _getBlock(next, localOnly: localOnly);
      if (nextBlock == null) {
        return null;
      }
      blocks.add((next, nextBlock));
    }

    return blocks;
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
          return _decodeLinkCid(link.hash);
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
      final linkCid = _decodeLinkCid(link.hash);
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
        'Etag': '"$cidStr"',
      },
    );
  }

  /// Navigates to a sub-path within a directory
  Future<Response> _navigateDirectory(
    String rootCid,
    PBNode directory,
    String subPath,
    Request request, {
    int indexDepth = 0,
  }) async {
    final pathParts = subPath.split('/');
    final targetName = pathParts[0];
    final remainingPath = pathParts.length > 1
        ? pathParts.sublist(1).join('/')
        : '';

    // Find the link with matching name
    for (final link in directory.links) {
      final linkName = link.name;
      if (linkName == targetName) {
        final linkCid = _decodeLinkCid(link.hash);
        return await _serveContent(
          linkCid.encode(),
          remainingPath,
          request,
          indexDepth: indexDepth,
        );
      }
    }

    return Response.notFound('Path not found: $subPath');
  }

  /// Resolves [subPath] within a HAMT-sharded directory whose root shard is
  /// [rootBlock], then serves the resolved node.
  ///
  /// HAMT leaf links carry a fixed-width hex hash prefix before the entry
  /// name, and a bucket may hold a child shard instead of an entry, so each
  /// segment is resolved via [resolveHAMTSegment] — descending into
  /// sub-shards until a leaf link is found — mirroring the algorithm used
  /// by `UnixFSPathResolver`. With an empty [subPath] the shard is
  /// treated like a plain directory: `index.html` is served when present
  /// (subject to the same [_maxIndexHtmlDepth] cap) and otherwise a listing
  /// of the leaf entries is rendered.
  Future<Response> _serveHamtShard(
    Block rootBlock,
    String cidStr,
    String subPath,
    Request request, {
    int indexDepth = 0,
  }) async {
    var node = UnixFSNode.fromBlock(rootBlock);
    var level = 0;
    final parts = subPath.split('/').where((p) => p.isNotEmpty).toList();

    while (true) {
      if (parts.isEmpty) {
        // The path ends at the shard itself — serve index.html when the
        // shard contains one, else render a directory listing.
        final indexLink = await _hamtLookup(node, 'index.html', level);
        if (indexLink != null) {
          if (indexDepth >= _maxIndexHtmlDepth) {
            return Response.internalServerError(
              body: 'index.html resolution depth exceeded',
            );
          }
          final indexCid = _decodeLinkCid(indexLink.hash);
          return await _serveContent(
            indexCid.encode(),
            '',
            request,
            indexDepth: indexDepth + 1,
          );
        }
        final listing = await _hamtLeafLinks(node);
        return _renderDirectory(cidStr, PBNode(links: listing), request);
      }

      final segment = parts.first;
      final link = resolveHAMTSegment(node, segment, level);
      if (link == null) {
        return Response.notFound('Path not found: $subPath');
      }
      final linkCid = _decodeLinkCid(link.hash);
      if (link.name.length == hamtPrefixWidth(node.fanout)) {
        // The bucket holds a child shard, not the entry itself: descend and
        // resolve the same segment at the next level.
        node = await _hamtSubShard(linkCid);
        level++;
        continue;
      }
      // Leaf link — the segment is consumed; the child may itself be a
      // file, directory, or nested shard, so the remainder of the path is
      // resolved by _serveContent.
      final remaining = parts.sublist(1).join('/');
      return await _serveContent(
        linkCid.encode(),
        remaining,
        request,
        indexDepth: indexDepth,
      );
    }
  }

  /// Follows [name] through the HAMT shard tree rooted at [node], starting
  /// at bucket [level]. Returns the leaf link for [name], or `null` when it
  /// is not present in the shard.
  Future<PBLink?> _hamtLookup(UnixFSNode node, String name, int level) async {
    var current = node;
    var currentLevel = level;
    while (true) {
      final link = resolveHAMTSegment(current, name, currentLevel);
      if (link == null) return null;
      if (link.name.length != hamtPrefixWidth(current.fanout)) {
        return link;
      }
      current = await _hamtSubShard(_decodeLinkCid(link.hash));
      currentLevel++;
    }
  }

  /// Fetches the block addressed by [cid] and returns it as a HAMT shard
  /// node. Throws [StateError] when the block is missing or is not a shard.
  Future<UnixFSNode> _hamtSubShard(CID cid) async {
    final child = await _getBlock(cid);
    if (child == null) {
      throw StateError('Missing HAMT sub-shard block ${cid.encode()}');
    }
    final node = UnixFSNode.fromBlock(child);
    if (!node.isHAMTShard) {
      throw StateError('HAMT sub-shard link is not a shard: ${cid.encode()}');
    }
    return node;
  }

  /// Collects the leaf links of the HAMT shard tree rooted at [node] with
  /// their hash-prefix stripped, for rendering a directory listing.
  /// Sub-shard links (names of exactly the prefix width) are traversed
  /// rather than listed.
  Future<List<PBLink>> _hamtLeafLinks(UnixFSNode node) async {
    final links = <PBLink>[];
    final pending = <UnixFSNode>[node];
    var visited = 0;
    while (pending.isNotEmpty) {
      if (++visited > _defaultMaxCarBlocks) {
        throw StateError('HAMT listing exceeded maximum node count');
      }
      final shard = pending.removeLast();
      final width = hamtPrefixWidth(shard.fanout);
      for (final link in shard.pbNode.links) {
        if (link.name.length == width) {
          pending.add(await _hamtSubShard(_decodeLinkCid(link.hash)));
        } else if (link.name.length > width) {
          links.add(
            PBLink(
              hash: link.hash,
              name: link.name.substring(width),
              size: link.size,
            ),
          );
        } else {
          throw StateError(
            'Invalid HAMT link name shorter than the $width-char prefix: '
            '${link.name}',
          );
        }
      }
    }
    return links;
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

  /// Returns `true` if [request] is addressed to a subdomain-style gateway host.
  bool isSubdomainRequest(Request request) {
    final host = request.headers['host'];
    if (host == null) return false;
    return _parseSubdomainHost(host) != null;
  }

  /// Splits a `Host` header value into its hostname and port suffix.
  ///
  /// Returns `(hostname, ':port')`; the port part is empty when absent or
  /// unparseable. Bracketed IPv6 literals are handled per RFC 3986.
  (String, String) _splitHostPort(String host) {
    final h = host.trim();
    if (h.startsWith('[')) {
      final end = h.indexOf(']');
      if (end == -1) return (h, '');
      final rest = h.substring(end + 1);
      return (h.substring(0, end + 1), rest.startsWith(':') ? rest : '');
    }
    final idx = h.lastIndexOf(':');
    if (idx > 0 && idx < h.length - 1) {
      final port = h.substring(idx + 1);
      if (int.tryParse(port) != null) {
        return (h.substring(0, idx), h.substring(idx));
      }
    }
    return (h, '');
  }

  /// Whether [hostName] refers to a loopback gateway host where subdomain
  /// requests are always supported.
  bool _isLocalhostName(String hostName) {
    final lower = hostName.toLowerCase();
    return lower == 'localhost' ||
        lower == '127.0.0.1' ||
        lower == '::1' ||
        lower == '[::1]';
  }

  /// Parses a subdomain-style gateway host into a [SubdomainRequest].
  ///
  /// Returns `null` when the host does not match a configured subdomain pattern,
  /// allowing callers to fall back to the path gateway.
  SubdomainRequest? _parseSubdomainHost(String host) {
    // Strip an optional port and a single trailing FQDN dot before matching;
    // DNS labels are matched case-insensitively.
    var hostname = _splitHostPort(host).$1;
    if (hostname.endsWith('.')) {
      hostname = hostname.substring(0, hostname.length - 1);
    }
    final hostLower = hostname.toLowerCase();

    // Localhost subdomain requests are always supported.
    for (final localDomain in const ['localhost', '127.0.0.1']) {
      if (hostLower.endsWith('.ipfs.$localDomain') ||
          hostLower.endsWith('.ipns.$localDomain')) {
        return _parseSubdomainHostWithDomain(hostname, localDomain);
      }
    }

    // Production subdomain requests require a configured gateway domain.
    final domain = gatewayDomain?.toLowerCase();
    if (domain == null || domain.isEmpty) return null;

    if (hostLower == domain) return null; // bare gateway domain

    if (!hostLower.endsWith('.$domain')) return null;

    return _parseSubdomainHostWithDomain(hostname, domain);
  }

  SubdomainRequest? _parseSubdomainHostWithDomain(String host, String domain) {
    final domainParts = domain.split('.');
    final hostParts = host.split('.');
    final hostPartsLower = host.toLowerCase().split('.');
    if (hostParts.length <= domainParts.length + 1) return null;

    final namespaceIndex = hostParts.length - domainParts.length - 1;
    final namespace = hostPartsLower[namespaceIndex];
    if (namespace != 'ipfs' && namespace != 'ipns') return null;

    final identifierParts = hostParts.sublist(0, namespaceIndex);
    if (identifierParts.isEmpty) return null;

    // Multi-label `ipfs` identifiers are still parsed so [handleSubdomain]
    // can reject them with a spec-compliant 400 instead of silently falling
    // back to the path gateway. DNSLink `ipns` names legitimately span
    // multiple labels (`docs.ipfs.io.ipns.<gw>`) in addition to the inlined
    // single-label form.
    final identifier = identifierParts.join('.');
    if (identifier.isEmpty) return null;

    return SubdomainRequest(namespace, identifier, '', domain);
  }

  /// Validates the leftmost label of an `ipfs` subdomain as a CID.
  ///
  /// CIDv0 is converted to CIDv1 base32 so it can be represented as a DNS label.
  /// Returns `null` if [cidStr] cannot be parsed as a CID.
  CID? _validateSubdomainCid(String cidStr) {
    if (cidStr.isEmpty) return null;
    try {
      final cid = _decodeCid(cidStr);
      if (cid.version == 0) {
        // Convert CIDv0 to CIDv1 base32 for DNS-label compatibility.
        return CID.v1(
          cid.codec ?? 'dag-pb',
          cid.multihash,
          base: Multibase.base32,
        );
      }
      return cid;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } catch (e) {
      _logger.warning('CID validation failed for $cidStr: $e');
      return null;
    }
  }

  /// Resolves an `ipns` subdomain identifier to a CID string.
  ///
  /// The identifier may be a PeerId/IPNS key, a DNSLink-compatible domain in
  /// multi-label form (`docs.ipfs.io`), or an inlined single-label DNSLink
  /// name (`docs-ipfs-io`). DNSLink values pointing to `/ipns/<name>` are
  /// recursively resolved via [ipnsResolver]. Throws [Exception] on failure.
  Future<_SubdomainIpnsResolution> _resolveSubdomainIpns(String name) async {
    // 1. Try the IPNS resolver for PeerId / libp2p-key names.
    final ipnsName = _canonicalIpnsName(name);
    if (ipnsResolver != null && ipnsName != null) {
      try {
        return _SubdomainIpnsResolution(await ipnsResolver!(ipnsName));
      } catch (e) {
        _logger.warning('IPNS resolver failed for $name: $e');
        // Continue to the DNSLink fallback only when the identifier could
        // still be a DNS name.
        if (_dnsLinkNameCandidates(name).isEmpty) rethrow;
      }
    }

    // 2. Try DNSLink resolution for DNS-like names.
    if (subdomainDNSLinkResolver) {
      for (final dnsName in _dnsLinkNameCandidates(name)) {
        final resolver = dnsLinkResolver ?? _defaultDnsLinkResolver;
        final result = await resolver(dnsName);
        if (result == null) continue;
        final path = result.path;
        if (path.startsWith('/ipfs/')) {
          final cidStr = path.substring(6);
          // Validate the CID before returning it.
          final cid = _validateSubdomainCid(cidStr);
          if (cid == null) {
            throw Exception('DNSLink resolved to invalid CID: $cidStr');
          }
          return _SubdomainIpnsResolution(
            cid.encode(),
            dnsLinkDomain: dnsName,
            ttlSeconds: result.ttlSeconds,
          );
        } else if (path.startsWith('/ipns/')) {
          final innerName = path.substring(6);
          if (ipnsResolver == null) {
            throw Exception('IPNS resolver unavailable for DNSLink /ipns path');
          }
          return _SubdomainIpnsResolution(
            await ipnsResolver!(innerName),
            dnsLinkDomain: dnsName,
            ttlSeconds: result.ttlSeconds,
          );
        }
      }
    }

    throw Exception('Invalid IPNS name in subdomain');
  }

  /// Returns the canonical IPNS name for [name] when it is a PeerId or
  /// libp2p-key identifier, or `null` when it should be treated as a DNSLink
  /// name instead.
  String? _canonicalIpnsName(String name) {
    if (_looksLikeIpnsName(name)) {
      // Base36/base32 names are case-insensitive DNS labels and are
      // normalized to lowercase; base58btc names are case-sensitive and are
      // kept as-is.
      final lower = name.toLowerCase();
      if (lower.startsWith('k') || lower.startsWith('b')) {
        return lower;
      }
      return name;
    }
    // A single-label identifier may be the inlined form of a name that only
    // becomes a valid IPNS name after de-inlining (e.g. a `….k` peer-id
    // suffix stored as `…-k`).
    if (!name.contains('.')) {
      final deInlined = _deInlineDnsLinkName(name);
      if (deInlined != name && _looksLikeIpnsName(deInlined)) {
        return deInlined.toLowerCase();
      }
    }
    return null;
  }

  /// Returns the DNS names that [name] may refer to: the multi-label form,
  /// or the de-inlined interpretation of a single-label identifier per the
  /// subdomain gateway spec.
  List<String> _dnsLinkNameCandidates(String name) {
    if (_looksLikeDnsName(name)) {
      return [name];
    }
    if (!name.contains('.')) {
      final deInlined = _deInlineDnsLinkName(name);
      if (deInlined != name && _looksLikeDnsName(deInlined)) {
        return [deInlined];
      }
    }
    return const [];
  }

  /// Inlines a DNSLink name into a single DNS label per the subdomain
  /// gateway spec: every `-` becomes `--` and every `.` becomes `-`.
  String _inlineDnsLinkName(String domain) {
    return domain.replaceAll('-', '--').replaceAll('.', '-');
  }

  /// Reverses [_inlineDnsLinkName]: every standalone `-` becomes `.` and
  /// every `--` becomes `-`.
  String _deInlineDnsLinkName(String label) {
    const sentinel = '\u0000';
    return label
        .replaceAll('--', sentinel)
        .replaceAll('-', '.')
        .replaceAll(sentinel, '-');
  }

  bool _looksLikeIpnsName(String name) {
    // IPNS peer IDs are base36 (k...) or base58btc strings. Base36 multibase
    // peer IDs may be represented in subdomain form with a trailing '.k'
    // suffix.
    if (name.isEmpty) return false;
    final dotCount = '.'.allMatches(name).length;
    if (dotCount > 1) return false;
    final lower = name.toLowerCase();
    if (lower.startsWith('k')) {
      if (dotCount == 0) {
        try {
          PeerId.fromBase36(lower);
          return true;
        } catch (_) {
          return false;
        }
      }
      return lower.endsWith('.k');
    }
    if (dotCount == 0) {
      if (_isBase58btcPeerId(name)) return true;
      // A single-label CID (e.g. a base32 libp2p-key) is a valid IPNS name.
      try {
        _decodeCid(lower.startsWith('b') ? lower : name);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  bool _isBase58btcPeerId(String name) {
    try {
      PeerId.fromBase58(name);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Whether every label of a subdomain identifier is a syntactically valid
  /// DNS label: non-empty, at most 63 characters, and limited to
  /// `[a-zA-Z0-9-]`. Used to reject malformed `ipns` identifiers with a 400
  /// before any resolution is attempted.
  bool _isValidSubdomainIdentifier(String identifier) {
    if (identifier.isEmpty || identifier.length > 253) return false;
    final labelRegex = RegExp(r'^[a-zA-Z0-9-]+$');
    for (final label in identifier.split('.')) {
      if (label.isEmpty || label.length > 63) return false;
      if (!labelRegex.hasMatch(label)) return false;
    }
    return true;
  }

  bool _looksLikeDnsName(String name) {
    // A DNS name contains at least one dot and only DNS-label characters.
    if (name.isEmpty || !name.contains('.')) return false;
    final dnsLabelRegex = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9-]*$');
    for (final label in name.split('.')) {
      if (label.isEmpty) return false;
      if (!dnsLabelRegex.hasMatch(label)) return false;
      if (label.length > 63) return false;
    }
    return name.length <= 253;
  }

  Future<DnsLinkResult?> _defaultDnsLinkResolver(String domain) async {
    final cid = await utils_dnslink.DNSLinkResolver.resolve(domain);
    if (cid != null && cid.isNotEmpty) {
      return DnsLinkResult('/ipfs/$cid', ttlSeconds: 60);
    }
    return null;
  }

  /// The effective request scheme, honoring `X-Forwarded-Proto` when the
  /// gateway sits behind a trusted TLS-terminating reverse proxy
  /// ([trustForwardedHeaders]).
  String _forwardedScheme(Request request) {
    if (trustForwardedHeaders) {
      final forwarded = request.headers['x-forwarded-proto']
          ?.split(',')
          .first
          .trim()
          .toLowerCase();
      if (forwarded == 'https') return 'https';
      if (forwarded == 'http') return 'http';
    }
    final scheme = request.requestedUri.scheme;
    return scheme.isEmpty ? 'http' : scheme;
  }

  /// URI router for `ipfs://` and `ipns://` addresses (subdomain gateway
  /// spec §4.4). Responds with a redirect to the equivalent path-gateway
  /// URL on this host, from which regular path/subdomain logic applies.
  Response _handleUriRouter(Request request, String uriValue) {
    final uri = Uri.tryParse(uriValue);
    if (uri == null || (uri.scheme != 'ipfs' && uri.scheme != 'ipns')) {
      return Response(
        400,
        body: 'Invalid uri query parameter',
        headers: const {'Content-Type': 'text/plain; charset=utf-8'},
      );
    }

    // `ipfs://<root>/<path>` places the root in the authority component;
    // `ipfs:<root>/<path>` keeps it in the first path segment.
    final String root;
    final String rest;
    if (uri.host.isNotEmpty) {
      root = uri.host;
      rest = uri.path;
    } else {
      final segments = uri.pathSegments;
      if (segments.isEmpty || segments.first.isEmpty) {
        return Response(
          400,
          body: 'Invalid uri query parameter',
          headers: const {'Content-Type': 'text/plain; charset=utf-8'},
        );
      }
      root = segments.first;
      rest = segments.length > 1 ? '/${segments.sublist(1).join('/')}' : '';
    }
    // Unreachable: `root` is either the (non-empty) URI host or the first
    // path segment, which is checked to be non-empty above.
    // coverage:ignore-start
    if (root.isEmpty) {
      return Response(
        400,
        body: 'Invalid uri query parameter',
        headers: const {'Content-Type': 'text/plain; charset=utf-8'},
      );
    }
    // coverage:ignore-end

    final scheme = _forwardedScheme(request);
    final host = request.headers['host'] ?? request.url.authority;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return Response.movedPermanently(
      '$scheme://$host/${uri.scheme}/$root$rest$query',
    );
  }

  /// Attempts the spec-mandated migration of a path-gateway request to the
  /// equivalent subdomain URL (subdomain gateway spec §3.1.1.1/§4.1).
  ///
  /// Returns a `301 Moved Permanently` response when the subdomain gateway
  /// is enabled and the request targets a known gateway host (`localhost`
  /// or the configured [gatewayDomain]) without carrying the content root
  /// in the `Host` header. Returns `null` when the redirect does not apply
  /// and the request should be served by the regular path gateway.
  Response? _subdomainMigrationRedirect(
    Request request,
    String namespace,
    String rootIdentifier,
    String subPath,
  ) {
    if (!enableSubdomainGateway) return null;

    final hostHeader = request.headers['host'] ?? request.url.authority;
    if (hostHeader.isEmpty) return null;

    // Requests already addressed to a subdomain host are handled by
    // [handleSubdomain]; there is nothing to migrate.
    if (_parseSubdomainHost(hostHeader) != null) return null;

    final requestSplit = _splitHostPort(hostHeader);
    final requestHostName = requestSplit.$1.toLowerCase();
    final configured = gatewayDomain?.toLowerCase();

    // Only migrate requests that arrived on a known gateway host; unknown
    // hosts keep plain path-gateway semantics.
    final isLocal = _isLocalhostName(requestHostName);
    final isConfigured =
        configured != null &&
        configured.isNotEmpty &&
        requestHostName == configured;
    if (!isLocal && !isConfigured) return null;

    // X-Forwarded-Host selects a different public domain for the subdomain
    // gateway (spec §2.1.3). The header is trivially spoofable by direct
    // clients, so it is only honored behind a trusted reverse proxy
    // ([trustForwardedHeaders]).
    var baseDomain = requestHostName;
    var portPart = requestSplit.$2;
    if (trustForwardedHeaders) {
      final forwardedHost = request.headers['x-forwarded-host']
          ?.split(',')
          .first
          .trim();
      if (forwardedHost != null && forwardedHost.isNotEmpty) {
        final fwdSplit = _splitHostPort(forwardedHost);
        baseDomain = fwdSplit.$1.toLowerCase();
        portPart = fwdSplit.$2;
      }
    }

    // The content root identifier must be convertible to a single
    // case-insensitive DNS label: CIDv0 becomes CIDv1 base32, DNSLink names
    // are inlined, and base58btc peer IDs become base36.
    final String? identifier;
    if (namespace == 'ipfs') {
      final cid = _validateSubdomainCid(rootIdentifier);
      if (cid == null) return null; // let the path handler report the 400
      identifier = cid.encode();
    } else {
      identifier = _subdomainCompatibleIpnsName(rootIdentifier);
    }
    if (identifier == null || identifier.isEmpty || identifier.length > 63) {
      return null;
    }

    final scheme = _forwardedScheme(request);
    final pathPart = subPath.isEmpty ? '/' : '/$subPath';
    final queryPart = request.url.hasQuery ? '?${request.url.query}' : '';
    return Response.movedPermanently(
      '$scheme://$identifier.$namespace.$baseDomain$portPart'
      '$pathPart$queryPart',
    );
  }

  /// Converts an `/ipns/<name>` path identifier into the single DNS label
  /// used on a subdomain gateway, or `null` when it cannot be represented.
  String? _subdomainCompatibleIpnsName(String name) {
    if (name.isEmpty || name.contains('%')) return null;
    if (_looksLikeDnsName(name)) {
      // DNSLink names with multiple labels must be inlined into a single
      // label (spec §2.1.1).
      return _inlineDnsLinkName(name);
    }
    if (_looksLikeIpnsName(name)) {
      if (_isBase58btcPeerId(name)) {
        // Case-sensitive base58btc cannot survive a DNS label; use the
        // case-insensitive base36 multibase form instead.
        try {
          return PeerId.fromBase58(name).toBase36();
        } catch (_) {
          return null;
        }
      }
      return name.toLowerCase();
    }
    return null;
  }

  /// Handles subdomain-based gateway requests (`{cid}.ipfs.{gateway}` or
  /// `{name}.ipns.{gateway}`).
  Future<Response> handleSubdomain(Request request) async {
    final host = request.headers['host'];
    if (host == null) {
      return _invalidSubdomainResponse('Missing host header');
    }

    final sub = _parseSubdomainHost(host);
    if (sub == null) {
      return _invalidSubdomainResponse('Invalid IPFS subdomain');
    }

    // Optional TLS redirect for non-localhost production domains.
    final redirect = _subdomainTlsRedirect(request, sub);
    if (redirect != null) {
      _recordGatewayRequest(
        request.method,
        request.url.path,
        redirect.statusCode,
      );
      return redirect;
    }

    // Reject percent-encoded identifiers up front: a DNS label cannot
    // contain `%`, so this is always a malformed subdomain host.
    if (sub.identifier.contains('%')) {
      return _invalidSubdomainResponse('Invalid subdomain identifier');
    }

    // On a subdomain gateway the URL path addresses content below the root
    // carried in the Host header.
    final subPath = request.url.path;

    Response response;
    String? ipnsPath;
    int? ipnsTtl;
    String? dnsLinkDomain;

    try {
      if (sub.namespace == 'ipfs') {
        // The ipfs identifier must be a single DNS label (≤63 chars) holding
        // a case-insensitive CIDv1. CIDv0 is converted to CIDv1 base32.
        if (sub.identifier.contains('.') || sub.identifier.length > 63) {
          response = _invalidCidResponse();
        } else {
          final cid = _validateSubdomainCid(sub.identifier);
          if (cid == null) {
            response = _invalidCidResponse();
          } else {
            final cidStr = cid.encode();
            ipnsPath = '/ipfs/$cidStr';
            final denylisted = _checkDenylist(
              subPath.isEmpty ? ipnsPath : '$ipnsPath/$subPath',
            );
            if (denylisted != null) {
              response = denylisted;
            } else {
              final negotiation = _negotiateTrustless(request);
              final negError = negotiation.error;
              if (negError != null) {
                response = negError;
              } else if (negotiation.format != null) {
                response = await _serveTrustless(
                  cid,
                  subPath,
                  negotiation,
                  request,
                );
              } else {
                response = await _serveContent(cidStr, subPath, request);
              }
            }
          }
        }
      } else {
        // ipns
        ipnsPath = '/ipns/${sub.identifier}';
        final denylisted = _checkDenylist(
          subPath.isEmpty ? ipnsPath : '$ipnsPath/$subPath',
        );
        if (denylisted != null) {
          response = denylisted;
        } else if (!_isValidSubdomainIdentifier(sub.identifier)) {
          response = _invalidSubdomainResponse(
            'Invalid IPNS name in subdomain',
          );
        } else {
          final resolution = await _resolveSubdomainIpns(sub.identifier);
          final cidStr = resolution.cid;
          final cid = _validateSubdomainCid(cidStr);
          if (cid == null) {
            response = _badGatewayResponse('Invalid IPNS resolution result');
          } else {
            dnsLinkDomain = resolution.dnsLinkDomain;
            ipnsTtl = resolution.ttlSeconds ?? _defaultIpnsTtlSeconds;
            // The resolved CID must be checked too: an allowed IPNS name
            // must not become a proxy for denylisted content.
            final resolvedDenylisted = _checkDenylist(
              subPath.isEmpty ? '/ipfs/$cidStr' : '/ipfs/$cidStr/$subPath',
            );
            if (resolvedDenylisted != null) {
              response = resolvedDenylisted;
            } else {
              final negotiation = _negotiateTrustless(request);
              final negError = negotiation.error;
              if (negError != null) {
                response = negError;
              } else if (negotiation.format == TrustlessFormat.ipnsRecord) {
                response = await _serveIpnsRecord(
                  sub.identifier,
                  request,
                  negotiation,
                );
              } else if (negotiation.format != null) {
                response = await _serveTrustless(
                  cid,
                  subPath,
                  negotiation,
                  request,
                  ipnsPath: ipnsPath,
                );
              } else {
                response = await _serveContent(cidStr, subPath, request);
              }
            }
          }
        }
      }
    } on FormatException catch (e) {
      _logger.warning('Invalid CID in subdomain: ${sub.identifier} ($e)');
      response = _invalidCidResponse();
    } on _DenylistBlockedException {
      // A denylisted child block was reached while traversing the DAG.
      response = _denylistBlockedResponse();
    } catch (e, stackTrace) {
      _logger.error(
        'Error serving content for subdomain ${sub.identifier}',
        e,
        stackTrace,
      );
      response = _badGatewayResponse(e.toString());
    }

    response = _applySubdomainResponseHeaders(
      response,
      sub,
      ipnsPath: ipnsPath,
      ipnsTtl: ipnsTtl,
      dnsLinkDomain: dnsLinkDomain,
    );

    // HEAD is GET-equivalent minus the payload (spec §1.2); the subdomain
    // middleware intercepts all methods, so strip the body here.
    if (request.method == 'HEAD') {
      response = Response(response.statusCode, headers: response.headers);
    }

    _recordGatewayRequest(
      request.method,
      request.url.path,
      response.statusCode,
    );
    return response;
  }

  Response? _subdomainTlsRedirect(Request request, SubdomainRequest sub) {
    if (!subdomainTLSRedirect) return null;
    if (sub.gatewayDomain == 'localhost' || sub.gatewayDomain == '127.0.0.1') {
      return null;
    }

    // Determine whether the request was made over HTTP. shelf's [Request.url]
    // strips the origin, so the original scheme is read from requestedUri.
    // X-Forwarded-Proto is only trusted behind a reverse proxy that rewrites
    // it ([trustForwardedHeaders]); otherwise it is spoofable and would let
    // a client suppress the HTTPS redirect.
    final forwardedProto = trustForwardedHeaders
        ? request.headers['x-forwarded-proto']
        : null;
    final scheme = request.requestedUri.scheme;
    if ((forwardedProto != null && forwardedProto != 'http') ||
        (forwardedProto == null && scheme != 'http')) {
      return null;
    }

    final host = request.headers['host'] ?? sub.gatewayDomain;
    final path = request.url.path;
    final location = 'https://$host${path.startsWith('/') ? path : '/$path'}';
    return Response.movedPermanently(location);
  }

  Response _applySubdomainResponseHeaders(
    Response response,
    SubdomainRequest sub, {
    String? ipnsPath,
    int? ipnsTtl,
    String? dnsLinkDomain,
  }) {
    final headers = Map<String, String>.from(response.headers);
    headers['Access-Control-Allow-Origin'] = '*';
    // Never set Access-Control-Allow-Credentials for subdomain origins.
    headers.remove('Access-Control-Allow-Credentials');
    headers['X-IPFS-Path'] = ipnsPath ?? '/${sub.namespace}/${sub.identifier}';
    if (sub.namespace == 'ipns') {
      headers['Cache-Control'] =
          'public, max-age=${ipnsTtl ?? _defaultIpnsTtlSeconds}';
    }
    if (dnsLinkDomain != null && dnsLinkDomain.isNotEmpty) {
      headers['X-IPFS-DNSLink'] = dnsLinkDomain;
    }
    return response.change(headers: headers);
  }

  Response _invalidCidResponse() {
    return Response(
      400,
      body: 'Invalid CID in subdomain',
      headers: {'Content-Type': 'text/plain; charset=utf-8'},
    );
  }

  Response _invalidSubdomainResponse(String body) {
    return Response(
      400,
      body: body,
      headers: {'Content-Type': 'text/plain; charset=utf-8'},
    );
  }

  Response _badGatewayResponse(String message) {
    return Response(
      502,
      body: 'Bad Gateway: $message',
      headers: {'Content-Type': 'text/plain; charset=utf-8'},
    );
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

  /// Decodes a CID string, tolerating identity multihashes with an empty
  /// digest (e.g. the `bafkqaaa` probe CID) which the standard multihash
  /// decoder rejects. Throws [FormatException] for invalid input.
  CID _decodeCid(String cidStr) {
    final cid = tryDecodeCidLenient(cidStr);
    if (cid == null) {
      throw FormatException('Invalid CID: $cidStr');
    }
    return cid;
  }

  /// Helper method to get a block by [CID].
  ///
  /// Identity CIDs (multihash code `0x00`) carry the block data inside the
  /// digest and are synthesized by the shared fetch pipeline without
  /// touching the store or network — but only after the denylist gate has
  /// run, so a denylisted identity CID is still blocked.
  Future<Block?> _getBlock(CID cid, {bool localOnly = false}) {
    return _blockFetcher.fetch(cid.encode(), localOnly: localOnly);
  }

  /// Helper method to get a block by CID string.
  ///
  /// First tries the local blockstore, then falls back to Bitswap if a
  /// [bitswapHandler] is available and running. When [localOnly] is true
  /// (a `Cache-Control: only-if-cached` request), Bitswap is skipped.
  Future<Block?> _getBlockByCid(String cidStr, {bool localOnly = false}) {
    return _blockFetcher.fetch(cidStr, localOnly: localOnly);
  }

  /// Local-store leg of [_blockFetcher]; lookup errors are logged and
  /// reported as a miss so Bitswap can still be attempted.
  Future<Block?> _localGetBlock(String cidStr) async {
    try {
      final response = await blockStore.getBlock(cidStr);
      if (response.found) {
        return response.block.toBlock();
      }
    } catch (e, stackTrace) {
      _logger.error('Error getting block $cidStr', e, stackTrace);
    }
    return null;
  }

  /// Bitswap leg of [_blockFetcher]; retrieval failures are logged and
  /// reported as a miss rather than failing the request.
  Future<Block?> _wantBlockBitswap(String cidStr) async {
    final bitswap = bitswapHandler;
    if (bitswap == null) {
      return null;
    }
    try {
      _logger.debug('Attempting Bitswap retrieval for $cidStr');
      return await bitswap.wantBlock(cidStr);
    } catch (e, stackTrace) {
      _logger.warning('Bitswap retrieval failed for $cidStr', e, stackTrace);
      return null;
    }
  }
}
