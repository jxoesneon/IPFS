// src/core/ipfs_node/content_routing_handler.dart
import 'dart:async';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/utils/dnslink_resolver.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/routing/content_routing.dart';
import 'package:dart_ipfs/src/routing/delegated_routing.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';

/// Handles content routing operations with fallback strategies
class ContentRoutingHandler {
  final IPFSConfig _config;
  final NetworkHandler _networkHandler;
  late final Logger _logger;
  late final ContentRouting _contentRouting;
  late final DelegatedRoutingHandler _delegatedRouting;

  ContentRoutingHandler(
    this._config,
    this._networkHandler, {
    ContentRouting? contentRouting,
    DelegatedRoutingHandler? delegatedRouting,
  }) {
    _logger = Logger('ContentRoutingHandler',
        debug: _config.debug, verbose: _config.verboseLogging);

    _contentRouting =
        contentRouting ?? ContentRouting(_config, _networkHandler);
    _delegatedRouting = delegatedRouting ??
        DelegatedRoutingHandler(
            delegateEndpoint: _config.network.delegatedRoutingEndpoint);

    _logger.debug('ContentRoutingHandler instance created');
  }

  /// Starts the content routing services
  Future<void> start() async {
    _logger.debug('Starting ContentRoutingHandler...');

    try {
      await _contentRouting.start();
      _logger.verbose('DHT-based content routing started');

      _logger.debug('ContentRoutingHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start ContentRoutingHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the content routing services
  Future<void> stop() async {
    _logger.debug('Stopping ContentRoutingHandler...');

    try {
      await _contentRouting.stop();
      _logger.verbose('DHT-based content routing stopped');

      _logger.debug('ContentRoutingHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop ContentRoutingHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Finds providers for a given CID using multiple routing strategies
  Future<List<String>> findProviders(String cid) async {
    _logger.debug('Finding providers for CID: $cid');

    try {
      // First try DHT-based routing
      _logger.verbose('Attempting DHT-based provider lookup');
      final dhtProviders = await _contentRouting.findProviders(cid);

      if (dhtProviders.isNotEmpty) {
        _logger.debug('Found ${dhtProviders.length} providers via DHT');
        return dhtProviders;
      }

      // If DHT fails, try delegated routing
      _logger.verbose('DHT lookup failed, trying delegated routing');
      // Convert string CID to CID object
      final cidObj = CID.decode(cid);

      final delegatedResponse = await _delegatedRouting.findProviders(cidObj);

      if (delegatedResponse.isSuccess &&
          delegatedResponse.providers.isNotEmpty) {
        _logger.debug(
            'Found ${delegatedResponse.providers.length} providers via delegated routing');
        return delegatedResponse.providers;
      }

      _logger.warning('No providers found for CID: $cid');
      return [];
    } catch (e, stackTrace) {
      _logger.error('Error finding providers', e, stackTrace);
      return [];
    }
  }

  /// Resolves a DNSLink to its corresponding CID
  Future<String?> resolveDNSLink(String domainName) async {
    _logger.debug('Resolving DNSLink for domain: $domainName');

    try {
      // First try direct DNS resolution
      _logger.verbose('Attempting direct DNSLink resolution');
      final cid = await DNSLinkResolver.resolve(domainName);

      if (cid != null) {
        _logger.debug('Resolved DNSLink via DNS: $cid');
        return cid;
      }

      // If direct resolution fails, try DHT-based resolution
      _logger.verbose('DNS resolution failed, trying DHT-based resolution');
      final dhtCid = await _contentRouting.resolveDNSLink(domainName);

      if (dhtCid != null) {
        _logger.debug('Resolved DNSLink via DHT: $dhtCid');
        return dhtCid;
      }

      _logger.warning('Failed to resolve DNSLink for domain: $domainName');
      return null;
    } catch (e, stackTrace) {
      _logger.error('Error resolving DNSLink', e, stackTrace);
      return null;
    }
  }

  /// Gets the current status of the content routing handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'dht_routing_enabled': true,
      'delegated_routing_enabled':
          _config.network.delegatedRoutingEndpoint != null,
      'delegated_endpoint': _config.network.delegatedRoutingEndpoint,
    };
  }
}
