import 'dart:async';
import '../protocols/dht/dht_client.dart'; // Import DHT client
import '../utils/dnslink_resolver.dart'; // Import DNSLink resolver

/// Handles content routing operations for an IPFS node.
class ContentRouting {
  final DHTClient _dhtClient;

  ContentRouting(config) : _dhtClient = DHTClient(config);

  /// Starts the content routing services.
  Future<void> start() async {
    try {
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
      return providers;
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
