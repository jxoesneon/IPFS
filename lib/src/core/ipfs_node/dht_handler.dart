import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:p2plib/p2plib.dart' show PeerId;
import 'package:dart_ipfs/src/utils/keystore.dart';
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
  final Datastore _storage; // Add storage field

  DHTHandler(config, P2plibRouter router, NetworkHandler networkHandler)
      : dhtClient = DHTClient(networkHandler: networkHandler),
        _keystore = Keystore(config),
        _router = router,
        _storage = Datastore(config.datastorePath) {
    // Initialize storage in constructor
    _storage.init();
  }

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
  @override
  Future<List<V_PeerInfo>> findProviders(CID cid) async {
    try {
      final providers = await dhtClient.findProviders(cid.toString());
      if (providers.isEmpty) {
        print(
            'No providers found for CID ${cid.toString()}. Attempting alternative discovery methods...');
      } else {
        print('Found providers for CID ${cid.toString()}: ${providers.length}');
      }

      // Convert PeerId objects to V_PeerInfo objects
      return providers.map((peerId) {
        final peerInfo = V_PeerInfo()..peerId = peerId.value;
        peerInfo.addresses
            .addAll([]); // Use addAll() instead of direct assignment
        peerInfo.protocols.addAll([]);
        return peerInfo;
      }).toList();
    } catch (e) {
      print('Error finding providers for CID ${cid.toString()}: $e');
      return [];
    }
  }

  /// Publishes a value to the DHT network under a given key.
  @override
  Future<void> putValue(Key key, Value value) async {
    try {
      // Convert Key and Value objects to strings for the DHT client
      await dhtClient.putValue(
        key.toString(), // Base58 encoded string
        value.toString(), // UTF-8 decoded string
      );
      print('Published value under key ${key.toString()}.');
    } catch (e) {
      print('Error publishing value under key ${key.toString()}: $e');
    }
  }

  /// Retrieves a value from the DHT network by its key.
  @override
  Future<Value> getValue(Key key) async {
    try {
      final value = await dhtClient.getValue(key.toString());
      if (value != null) {
        print('Retrieved value for key ${key.toString()}.');
        return Value.fromString(value);
      } else {
        print('Value for key ${key.toString()} not found.');
        throw Exception('Value not found');
      }
    } catch (e) {
      print('Error retrieving value for key ${key.toString()}: $e');
      throw Exception('Failed to get value: $e');
    }
  }

  /// Resolves an IPNS name to its corresponding CID using alternative methods if necessary.
  Future<String> resolveIPNS(String ipnsName) async {
    if (!isValidPeerID(ipnsName)) {
      throw ArgumentError('Invalid IPNS name: $ipnsName');
    }

    String? resolvedCid;
    try {
      final value = await getValue(Key.fromString(ipnsName));
      resolvedCid = value.toString(); // Convert Value to String
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
      await putValue(
          Key.fromString(keyPair.publicKey), // Convert String to Key
          Value.fromString(cid) // Convert String to Value
          );
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
      final dnsKey = Key.fromString('dnslink:$domainName');
      final value = await getValue(dnsKey);
      final cid = extractCIDFromResponse(value.toString());
      if (cid != null) {
        print('Resolved DNSLink for domain $domainName to CID: $cid');
        return cid;
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

  // Add getter for storage
  Datastore get storage => _storage;
}
