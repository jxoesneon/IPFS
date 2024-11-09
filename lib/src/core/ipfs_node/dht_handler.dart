import 'package:http/http.dart' as http;
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:p2plib/p2plib.dart' show PeerId;
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/utils/dnslink_resolver.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
// lib/src/core/ipfs_node/dht_handler.dart

/// Handles DHT operations for an IPFS node.
class DHTHandler implements IDHTHandler {
  final DHTClient dhtClient;
  final Keystore _keystore; // Add a reference to the Keystore
  final P2plibRouter _router;

  DHTHandler(config, P2plibRouter router, NetworkHandler networkHandler)
      : dhtClient = DHTClient(networkHandler: networkHandler),
        _keystore = Keystore(config),
        _router = router;

  /// Starts the DHT client.
  Future<void> start() async {
    try {
      await dhtClient.start();
      print('DHT client started.');
    } catch (e) {
      print('Error starting DHT client: $e');
    }
  }

  /// Stops the DHT client.
  Future<void> stop() async {
    try {
      await dhtClient.stop();
      print('DHT client stopped.');
    } catch (e) {
      print('Error stopping DHT client: $e');
    }
  }

  /// Finds providers for a given CID in the DHT network.
  Future<List<String>> findProviders(String cid) async {
    try {
      final providers = await dhtClient.findProviders(cid);
      if (providers.isEmpty) {
        print(
            'No providers found for CID $cid. Attempting alternative discovery methods...');
        // Implement alternative provider discovery methods here
      } else {
        print('Found providers for CID $cid: ${providers.length}');
      }
      // Convert PeerId objects to their string representations using Base58
      return providers.map((peerId) => _convertPeerIdToBase58(peerId)).toList();
    } catch (e) {
      print('Error finding providers for CID $cid: $e');
      return [];
    }
  }

  /// Publishes a value to the DHT network under a given key.
  Future<void> putValue(String key, String value) async {
    try {
      await dhtClient.putValue(key, value);
      print('Published value under key $key.');
    } catch (e) {
      print('Error publishing value under key $key: $e');
    }
  }

  /// Retrieves a value from the DHT network by its key.
  Future<String?> getValue(String key) async {
    try {
      final value = await dhtClient.getValue(key);
      if (value != null) {
        print('Retrieved value for key $key.');
        return value;
      } else {
        print('Value for key $key not found.');
        return null;
      }
    } catch (e) {
      print('Error retrieving value for key $key: $e');
      return null;
    }
  }

  /// Resolves an IPNS name to its corresponding CID using alternative methods if necessary.
  Future<String> resolveIPNS(String ipnsName) async {
    if (!isValidPeerID(ipnsName)) {
      throw ArgumentError('Invalid IPNS name: $ipnsName');
    }

    String? resolvedCid;
    try {
      resolvedCid = await getValue(ipnsName);
    } catch (e) {
      print('Error resolving IPNS name through DHT: $e');
    }

    // If resolution via DHT fails, use a public IPNS resolver
    if (resolvedCid == null) {
      try {
        final url = Uri.parse('https://ipfs.io/ipns/$ipnsName');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          resolvedCid = extractCIDFromResponse(response.body);
          if (resolvedCid != null) {
            print('Resolved IPNS name using public resolver: $resolvedCid');
          } else {
            throw Exception(
                'Failed to extract CID from public resolver response.');
          }
        } else {
          throw Exception(
              'Public resolver returned status code ${response.statusCode}');
        }
      } catch (e) {
        print('Error resolving IPNS name using public resolver: $e');
        throw Exception('Failed to resolve IPNS name using all methods.');
      }
    }

    return resolvedCid;
  }

  /// Publishes an IPNS record.
  Future<void> publishIPNS(String cid, {required String keyName}) async {
    // Get the IPNS key pair from the keystore
    final keyPair = _keystore.getKeyPair(keyName);

    if (!isValidCID(cid)) {
      throw ArgumentError('Invalid CID: $cid');
    }

    try {
      await putValue(keyPair.publicKey, cid);
      print('Published IPNS record for CID: $cid with key: $keyName');
    } catch (e) {
      print('Error publishing IPNS record: $e');
    }
  }

  /// Validates if a given string is a valid CID.
  bool isValidCID(String cid) =>
      cid.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cid);

  /// Validates if a given string is a valid peer ID.
  bool isValidPeerID(String peerId) =>
      peerId.isNotEmpty && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(peerId);

  /// Extracts a CID from an HTTP response body.
  String? extractCIDFromResponse(String responseBody) {
    // Placeholder logic to extract CID from response body
    // Implement actual extraction logic based on response format
    final match =
        RegExp(r'Qm[1-9A-HJ-NP-Za-km-z]{44}').firstMatch(responseBody);
    return match?.group(0);
  }

  P2plibRouter get router => _router;

  @override
  Future<List<V_PeerInfo>> findPeer(PeerId id) async {
    // Implementation here
    throw UnimplementedError('findPeer not yet implemented');
  }

  @override
  Future<void> provide(CID cid) async {
    // Implement interface method
  }

  /// Handles routing table updates when peer information changes
  @override
  Future<void> handleRoutingTableUpdate(V_PeerInfo peer) async {
    try {
      // Change routingTable to kademliaRoutingTable
      dhtClient.kademliaRoutingTable.updatePeer(peer);
      print('Updated routing table entry for peer: ${peer.peerId}');
    } catch (e) {
      print('Error updating routing table for peer ${peer.peerId}: $e');
    }
  }

  /// Handles requests from peers to provide content
  @override
  Future<void> handleProvideRequest(CID cid, PeerId provider) async {
    try {
      // Add the provider to the DHT client's provider store
      await dhtClient.addProvider(cid.toString(), provider.toString());
      print('Added provider ${provider.toString()} for CID ${cid.toString()}');
    } catch (e) {
      print('Error handling provide request for CID ${cid.toString()}: $e');
    }
  }

  /// Resolves a DNSLink to its corresponding CID.
  Future<String?> resolveDNSLink(String domainName) async {
    try {
      // First try using the DHT network to resolve the DNSLink
      final value = await getValue('dnslink:$domainName');
      if (value != null) {
        final cid = extractCIDFromResponse(value);
        if (cid != null) {
          print('Resolved DNSLink for domain $domainName to CID: $cid');
          return cid;
        }
      }

      // If DHT resolution fails, try using DNSLinkResolver
      final resolvedCid = await DNSLinkResolver.resolve(domainName);
      if (resolvedCid != null) {
        print(
            'Resolved DNSLink using resolver for domain $domainName: $resolvedCid');
        return resolvedCid;
      }

      print('Failed to resolve DNSLink for domain: $domainName');
      return null;
    } catch (e) {
      print('Error resolving DNSLink for domain $domainName: $e');
      return null;
    }
  }
}

/// Encodes PeerId to Base58 string
String _convertPeerIdToBase58(p2p.PeerId peerId) {
  // PeerId already contains the value as bytes
  return EncodingUtils.toBase58(peerId.value);
}
