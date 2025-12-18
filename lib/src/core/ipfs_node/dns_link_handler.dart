// src/core/ipfs_node/dns_link_handler.dart
import 'dart:async';
import 'dart:convert';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:http/http.dart' as http;

/// Handles DNSLink resolution with caching and multiple resolution strategies
class DNSLinkHandler {

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

  // Public resolvers for fallback
  static const List<String> _publicResolvers = [
    'https://dnslink.io/',
    'https://dnslink-resolver.example.com/',
    'https://ipfs.io/api/v0/dns/',
  ];

  final http.Client _client;

  /// Starts the DNSLink handler
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

  /// Resolves a DNSLink to its corresponding CID using multiple strategies
  Future<String?> resolve(String domainName) async {
    _logger.debug('Resolving DNSLink for domain: $domainName');

    try {
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

      // Try each resolver in sequence
      String? resolvedCid;

      for (final resolver in _publicResolvers) {
        try {
          _logger.verbose('Attempting resolution using: $resolver');
          resolvedCid = await _resolveWithPublicResolver(domainName, resolver);
          if (resolvedCid != null) {
            _cacheResult(domainName, resolvedCid);
            return resolvedCid;
          }
        } catch (e) {
          _logger.warning('Failed to resolve using $resolver: $e');
          continue;
        }
      }

      _logger.warning('Failed to resolve DNSLink for domain: $domainName');
      return null;
    } catch (e, stackTrace) {
      _logger.error('Error resolving DNSLink', e, stackTrace);
      return null;
    }
  }

  Future<String?> _resolveWithPublicResolver(
    String domainName,
    String resolver,
  ) async {
    _logger.verbose('Querying resolver: $resolver');

    final url = Uri.parse('$resolver$domainName');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final cid = _extractCIDFromResponse(jsonResponse);
      if (cid != null) {
        _logger.debug('Successfully resolved DNSLink using $resolver');
        return cid;
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
      'public_resolvers': _publicResolvers,
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
