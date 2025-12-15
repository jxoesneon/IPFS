// lib/src/core/ipfs_node/routing_handler.dart

import 'dart:convert';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ipfs/src/routing/content_routing.dart';
import 'package:dart_ipfs/src/utils/dnslink_resolver.dart'; // Import your DNSLinkResolver utility

/// Handles routing operations for an IPFS node.
class RoutingHandler {
  final ContentRouting _contentRouting;

  RoutingHandler(
    config,
    NetworkHandler networkHandler, {
    ContentRouting? contentRouting,
  }) : _contentRouting =
           contentRouting ?? ContentRouting(config, networkHandler);

  /// Starts the routing services.
  Future<void> start() async {
    try {
      await _contentRouting.start();
      print('Content routing started.');
    } catch (e) {
      print('Error starting content routing: $e');
    }
  }

  /// Stops the routing services.
  Future<void> stop() async {
    try {
      await _contentRouting.stop();
      print('Content routing stopped.');
    } catch (e) {
      print('Error stopping content routing: $e');
    }
  }

  /// Finds providers for a given CID using content routing.
  Future<List<String>> findProviders(String cid) async {
    try {
      final providers = await _contentRouting.findProviders(cid);
      if (providers.isEmpty) {
        print(
          'No providers found for CID $cid. Attempting alternative discovery methods...',
        );
        // Implement alternative provider discovery methods here
      } else {
        print('Found providers for CID $cid: ${providers.length}');
      }
      return providers;
    } catch (e) {
      print('Error finding providers for CID $cid: $e');
      return [];
    }
  }

  /// Resolves a DNSLink to its corresponding CID with comprehensive error handling.
  Future<String?> resolveDNSLink(String domainName) async {
    try {
      final cid = await DNSLinkResolver.resolve(
        domainName,
      ); // Use static access
      if (cid != null) {
        print('Resolved DNSLink for domain $domainName to CID: $cid');
        return cid;
      } else {
        throw Exception('DNSLink for domain $domainName not found.');
      }
    } catch (e) {
      print('Error resolving DNSLink for domain $domainName: $e');

      // Attempt alternative resolution methods, such as querying a public DNSLink resolver
      try {
        final url = Uri.parse(
          'https://dnslink-resolver.example.com/$domainName',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final resolvedCid = jsonDecode(response.body)['cid'];
          if (resolvedCid != null) {
            print('Resolved DNSLink using public resolver: $resolvedCid');
            return resolvedCid;
          } else {
            throw Exception(
              'Failed to extract CID from public resolver response.',
            );
          }
        } else {
          throw Exception(
            'Public resolver returned status code ${response.statusCode}',
          );
        }
      } catch (altError) {
        print('Alternative DNSLink resolution failed: $altError');
        return null;
      }
    }
  }
}
