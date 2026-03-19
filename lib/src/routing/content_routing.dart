import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';

import '../core/ipfs_node/network_handler.dart';
import '../protocols/dht/dht_client.dart'; // Import DHT client
import '../utils/base58.dart';
import '../utils/dnslink_resolver.dart'; // Import DNSLink resolver
import '../utils/logger.dart';

/// Handles content routing operations for an IPFS node.
class ContentRouting {
  /// Creates a content routing handler.
  ContentRouting(IPFSConfig config, NetworkHandler networkHandler)
    : _dhtClient = DHTClient(
        networkHandler: networkHandler,
        router: networkHandler.router,
      );
  final DHTClient _dhtClient;
  final _logger = Logger('ContentRouting');

  /// Starts the content routing services.
  Future<void> start() async {
    try {
      await _dhtClient.initialize();
      await _dhtClient.start();
      _logger.info('Content routing started.');
    } catch (e, stackTrace) {
      _logger.error('Error starting content routing', e, stackTrace);
    }
  }

  /// Stops the content routing services.
  Future<void> stop() async {
    try {
      await _dhtClient.stop();
      _logger.info('Content routing stopped.');
    } catch (e, stackTrace) {
      _logger.error('Error stopping content routing', e, stackTrace);
    }
  }

  /// Finds providers for a given CID in the DHT network.
  Future<List<String>> findProviders(String cid) async {
    try {
      final providers = await _dhtClient.findProviders(cid);
      if (providers.isEmpty) {
        _logger.info('No providers found for CID $cid.');
        // Implement alternative discovery methods if necessary
      } else {
        _logger.info('Found providers for CID $cid: ${providers.length}');
      }
      // Convert PeerId objects to strings using Base58 encoding
      return providers.map((peerId) => Base58().encode(peerId.value)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error finding providers for CID $cid', e, stackTrace);
      return [];
    }
  }

  /// Resolves a DNSLink to its corresponding CID.
  Future<String?> resolveDNSLink(String domainName) async {
    try {
      final cid = await DNSLinkResolver.resolve(domainName);
      if (cid != null) {
        _logger.info('Resolved DNSLink for domain $domainName to CID: $cid');
        return cid;
      } else {
        throw Exception('DNSLink for domain $domainName not found.');
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error resolving DNSLink for domain $domainName',
        e,
        stackTrace,
      );
      return null;
    }
  }
}
