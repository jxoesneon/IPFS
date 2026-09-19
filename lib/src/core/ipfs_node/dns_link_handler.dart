// src/core/ipfs_node/dns_link_handler.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/logger.dart';
import '../config/ipfs_config.dart';
import '../interfaces/i_lifecycle.dart';

/// Handles DNSLink resolution with caching and multiple resolution strategies.
///
/// The handler is registered in the service container and lifecycle-managed
/// by the node when [IPFSConfig.enableDNSLinkResolution] is set. [resolve]
/// tries, in order:
///
/// 1. the `dnslink.io` HTTPS resolver, which answers
///    `GET https://dnslink.io/<domain>` with a `{"cid"|"Path"|"Target"}`
///    JSON body, and
/// 2. a real DNS `TXT` lookup for `_dnslink.<domain>` via DNS-over-HTTPS
///    (dns.google), which is the record the DNSLink specification defines.
///
/// [resolve] returns `null` when no strategy yields a record; an individual
/// resolver failure is logged and the next strategy is tried.
class DNSLinkHandler implements ILifecycle {
  /// Creates a DNSLink handler with config and optional HTTP client.
  DNSLinkHandler(this._config, {http.Client? client})
    : _client = client ?? http.Client() {
    _logger = Logger(
      'DNSLinkHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
    _logger.debug('DNSLinkHandler instance created');
  }
  final IPFSConfig _config;
  late final Logger _logger;

  // Cache for resolved DNSLinks
  final Map<String, _CachedDNSLink> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  // JSON resolvers answering `GET <base><domain>` with a DNSLink record body.
  static const List<String> _jsonResolvers = ['https://dnslink.io/'];

  // DNS-over-HTTPS endpoint used for the real `_dnslink` TXT lookup.
  static const String _dohEndpoint = 'https://dns.google/resolve';

  static const Duration _requestTimeout = Duration(seconds: 5);

  final http.Client _client;

  /// Starts the DNSLink handler
  @override
  Future<void> start() async {
    _logger.debug('Starting DNSLinkHandler...');
    try {
      // Initialize cache
      _cache.clear();
      _logger.debug('DNSLinkHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start DNSLinkHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the DNSLink handler
  @override
  Future<void> stop() async {
    _logger.debug('Stopping DNSLinkHandler...');
    try {
      _cache.clear();
      _logger.debug('DNSLinkHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop DNSLinkHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Resolves a DNSLink to its corresponding CID using multiple strategies.
  ///
  /// Returns the resolved value (a CID or an `/ipfs/<cid>` path, depending on
  /// the strategy that answered), or `null` when every strategy fails or the
  /// domain has no DNSLink record.
  Future<String?> resolve(String domainName) async {
    _logger.debug('Resolving DNSLink for domain: $domainName');

    // Check cache first
    if (_cache.containsKey(domainName)) {
      final cached = _cache[domainName]!;
      if (!cached.isExpired) {
        _logger.verbose('Returning cached DNSLink for: $domainName');
        return cached.cid;
      } else {
        _logger.verbose('Cached DNSLink expired for: $domainName');
        _cache.remove(domainName);
      }
    }

    // Strategy 1: JSON HTTP resolvers.
    for (final resolver in _jsonResolvers) {
      try {
        _logger.verbose('Attempting resolution using: $resolver');
        final resolvedCid = await _resolveWithPublicResolver(
          domainName,
          resolver,
        );
        if (resolvedCid != null) {
          _cacheResult(domainName, resolvedCid);
          return resolvedCid;
        }
      } catch (e) {
        _logger.warning('Failed to resolve using $resolver: $e');
      }
    }

    // Strategy 2: real `_dnslink` TXT lookup via DNS-over-HTTPS.
    try {
      final target = await _resolveViaDnsTxt(domainName);
      if (target != null) {
        _cacheResult(domainName, target);
        return target;
      }
    } catch (e) {
      _logger.warning('DNS TXT lookup failed for $domainName: $e');
    }

    _logger.warning('Failed to resolve DNSLink for domain: $domainName');
    return null;
  }

  Future<String?> _resolveWithPublicResolver(
    String domainName,
    String resolver,
  ) async {
    _logger.verbose('Querying resolver: $resolver');

    final url = Uri.parse('$resolver${Uri.encodeComponent(domainName)}');
    final response = await _client.get(url).timeout(_requestTimeout);

    if (response.statusCode == 200) {
      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        return null;
      }
      if (decoded is Map<String, dynamic>) {
        final cid = _extractCIDFromResponse(decoded);
        if (cid != null) {
          _logger.debug('Successfully resolved DNSLink using $resolver');
          return cid;
        }
      }
    }

    return null;
  }

  /// Queries the `_dnslink.<domain>` TXT record via DNS-over-HTTPS and
  /// extracts the `dnslink=` target (e.g. `/ipfs/<cid>`).
  Future<String?> _resolveViaDnsTxt(String domainName) async {
    final query = '_dnslink.$domainName';
    final url = Uri.parse(
      '$_dohEndpoint?name=${Uri.encodeComponent(query)}&type=TXT',
    );
    final response = await _client.get(url).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      return null;
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final answers = decoded['Answer'];
    if (answers is! List) {
      return null;
    }

    for (final answer in answers) {
      if (answer is! Map<String, dynamic>) continue;
      // Type 16 is TXT. DoH returns TXT rdata as a quoted character-string;
      // quotes and whitespace are presentation artifacts, not record data.
      if (answer['type'] != 16) continue;
      final data = answer['data']?.toString() ?? '';
      final record = data.replaceAll('"', '').replaceAll(' ', '');
      if (record.startsWith('dnslink=')) {
        final target = record.substring('dnslink='.length);
        if (target.isNotEmpty) {
          _logger.debug(
            'Resolved DNSLink for $domainName via DNS TXT: $target',
          );
          return target;
        }
      }
    }
    return null;
  }

  String? _extractCIDFromResponse(Map<String, dynamic> response) {
    // Handle different response formats from various resolvers
    return response['Path']?.toString() ??
        response['cid']?.toString() ??
        response['Target']?.toString();
  }

  void _cacheResult(String domainName, String cid) {
    _logger.verbose('Caching DNSLink result for: $domainName');
    _cache[domainName] = _CachedDNSLink(cid: cid, timestamp: DateTime.now());
  }

  /// Gets the current status of the DNSLink handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'cache_size': _cache.length,
      'cache_duration_minutes': _cacheDuration.inMinutes,
      'public_resolvers': [..._jsonResolvers, _dohEndpoint],
    };
  }
}

/// Helper class for caching DNSLink resolutions
class _CachedDNSLink {
  _CachedDNSLink({required this.cid, required this.timestamp});
  final String cid;
  final DateTime timestamp;

  bool get isExpired =>
      DateTime.now().difference(timestamp) > DNSLinkHandler._cacheDuration;
}
