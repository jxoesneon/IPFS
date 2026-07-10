// src/core/ipfs_node/content_routing_handler.dart
import 'dart:async';

import 'package:http/http.dart' as http;

import '../../routing/content_routing.dart';
import '../../routing/delegated_routing.dart';
import '../../routing/ipni_client.dart';
import '../../routing/reframe_routing.dart';
import '../../utils/dnslink_resolver.dart';
import '../../utils/logger.dart';
import '../cid.dart';
import '../config/ipfs_config.dart';
import 'network_handler.dart';

/// Handles content routing operations with fallback strategies.
class ContentRoutingHandler {
  /// Creates a content routing handler with config and network handler.
  ContentRoutingHandler(
    this._config,
    this._networkHandler, {
    ContentRouting? contentRouting,
    DelegatedRoutingHandler? delegatedRouting,
    IPNIClient? ipniClient,
    ReframeRoutingClient? reframeClient,
    http.Client? dnsClient,
  }) : _dnsClient = dnsClient {
    _logger = Logger(
      'ContentRoutingHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );

    _contentRouting =
        contentRouting ?? ContentRouting(_config, _networkHandler);
    _delegatedRouting =
        delegatedRouting ??
        DelegatedRoutingHandler(
          delegateEndpoint: _config.network.delegatedRoutingEndpoint,
        );
    _ipniClient = ipniClient ?? _createIpniClient();
    _reframeClient = reframeClient ?? _createReframeClient();

    _logger.debug('ContentRoutingHandler instance created');
  }
  final IPFSConfig _config;
  final NetworkHandler _networkHandler;
  final http.Client? _dnsClient;
  late final Logger _logger;
  late final ContentRouting _contentRouting;
  late final DelegatedRoutingHandler _delegatedRouting;
  IPNIClient? _ipniClient;
  ReframeRoutingClient? _reframeClient;

  IPNIClient? _createIpniClient() {
    if (_config.network.ipniEndpoints.isEmpty) return null;
    return IPNIClient(endpoints: _config.network.ipniEndpoints);
  }

  ReframeRoutingClient? _createReframeClient() {
    if (_config.network.reframeEndpoints.isEmpty) return null;
    return ReframeRoutingClient(
      endpoints: _config.network.reframeEndpoints,
      useGetApi: true,
    );
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

      _ipniClient?.dispose();
      _ipniClient = null;
      _reframeClient?.dispose();
      _reframeClient = null;
      _delegatedRouting.dispose();

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

      // Convert string CID to CID object once for HTTP-based routers.
      final cidObj = CID.decode(cid);

      // Try IPNI next if configured.
      final ipniClient = _ipniClient;
      if (ipniClient != null) {
        _logger.verbose('DHT lookup empty, trying IPNI');
        try {
          final ipniResponse = await ipniClient.findProviders(cidObj);
          if (ipniResponse.isSuccess && ipniResponse.providers.isNotEmpty) {
            final providers = ipniResponse.providers
                .map((p) => p.peerId)
                .toList();
            _logger.debug('Found ${providers.length} providers via IPNI');
            return providers;
          }
        } catch (e, stackTrace) {
          _logger.warning('IPNI lookup failed', e, stackTrace);
        }
      }

      // Try Reframe if configured.
      final reframeClient = _reframeClient;
      if (reframeClient != null) {
        _logger.verbose('IPNI empty, trying Reframe');
        try {
          final reframeResponse = await reframeClient.findProviders(cidObj);
          if (reframeResponse.isSuccess &&
              reframeResponse.providers.isNotEmpty) {
            final providers = reframeResponse.providers
                .map((p) => p.peerId)
                .toList();
            _logger.debug('Found ${providers.length} providers via Reframe');
            return providers;
          }
        } catch (e, stackTrace) {
          _logger.warning('Reframe lookup failed', e, stackTrace);
        }
      }

      // If IPNI/Reframe are not configured or also empty, try delegated routing
      _logger.verbose('Trying delegated routing');
      final delegatedResponse = await _delegatedRouting.findProviders(cidObj);

      if (delegatedResponse.isSuccess &&
          delegatedResponse.providers.isNotEmpty) {
        _logger.debug(
          'Found ${delegatedResponse.providers.length} providers via delegated routing',
        );
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
      final cid = await DNSLinkResolver.resolve(domainName, client: _dnsClient);

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
      'ipni_routing_enabled': _ipniClient != null,
      'ipni_endpoints': _config.network.ipniEndpoints,
      'reframe_routing_enabled': _reframeClient != null,
      'reframe_endpoints': _config.network.reframeEndpoints,
      'delegated_routing_enabled':
          _config.network.delegatedRoutingEndpoint != null,
      'delegated_endpoint': _config.network.delegatedRoutingEndpoint,
    };
  }
}
