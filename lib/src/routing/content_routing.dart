import 'dart:async';

import '../protocols/dht/dht_client.dart'; // Import DHT client
import '../utils/dnslink_resolver.dart'; // Import DNSLink resolver
import '../core/ipfs_node/network_handler.dart';
import '../utils/base58.dart';

/// Handles content routing operations for an IPFS node.
class ContentRouting {
  final DHTClient _dhtClient;

  ContentRouting(config, NetworkHandler networkHandler)
      : _dhtClient = DHTClient(
          networkHandler: networkHandler,
          router: networkHandler.p2pRouter,
        );

  /// Starts the content routing services.
  Future<void> start() async {
    try {
      await _dhtClient.initialize();
      await _dhtClient.start();
      print('Content routing started.');
    } catch (e) {
      print('Error starting content routing: $e');
    }
  }

  /// Stops the content routing services.
  Future<void> stop() async {
    try {
      await _dhtClient.stop();
      print('Content routing stopped.');
    } catch (e) {
      print('Error stopping content routing: $e');
    }
  }

  /// Finds providers for a given CID in the DHT network.
  Future<List<String>> findProviders(String cid) async {
    try {
      final providers = await _dhtClient.findProviders(cid);
      if (providers.isEmpty) {
        print('No providers found for CID $cid.');
        // Implement alternative discovery methods if necessary
      } else {
        print('Found providers for CID $cid: ${providers.length}');
      }
      // Convert PeerId objects to strings using Base58 encoding
      return providers.map((peerId) => Base58().encode(peerId.value)).toList();
    } catch (e) {
      print('Error finding providers for CID $cid: $e');
      return [];
    }
  }

  /// Resolves a DNSLink to its corresponding CID.
  Future<String?> resolveDNSLink(String domainName) async {
    try {
      final cid = await DNSLinkResolver.resolve(domainName);
      if (cid != null) {
        print('Resolved DNSLink for domain $domainName to CID: $cid');
        return cid;
      } else {
        throw Exception('DNSLink for domain $domainName not found.');
      }
    } catch (e) {
      print('Error resolving DNSLink for domain $domainName: $e');
      return null;
    }
  }
}
