// src/protocols/dht/dht_handler.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:p2plib/p2plib.dart' show PeerId;
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:dart_ipfs/src/utils/dnslink_resolver.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/Interface_dht_handler.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/proto/generated/ipns/ipns.pb.dart';
import 'package:fixnum/fixnum.dart';

/// Handles DHT operations for an IPFS node.
class DHTHandler implements IDHTHandler {
  late final DHTClient dhtClient;
  final Keystore _keystore;
  final P2plibRouter _router;
  final Datastore _storage;

  final Set<String> _activeQueries = {};
  final Map<String, Set<String>> _providers = {};
  static const String _protocolVersion = '1.0.0';

  DHTHandler(config, this._router, NetworkHandler networkHandler)
    : _keystore = Keystore(),
      _storage = Datastore(config.datastorePath) {
    _storage.init();
    dhtClient = DHTClient(networkHandler: networkHandler, router: _router);
  }

  /// Starts the DHT client.
  Future<void> start() async {
    try {
      await dhtClient.start();
      print('DHT client started.');
    } catch (e) {
      print('Error starting DHT client: $e');
      rethrow;
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
      return providers
          .map((peer) => V_PeerInfo()..peerId = peer.value)
          .toList();
    } catch (e) {
      print('Error finding providers: $e');
      return [];
    }
  }

  /// Publishes a value to the DHT network under a given key.
  @override
  Future<void> putValue(Key key, Value value) async {
    try {
      final storageKey = '/dht/values/${key.toString()}';

      // Create a Block instance from the value bytes
      final block = await Block.fromData(
        value.bytes,
        format: 'raw', // Using raw format since this is DHT value data
      );

      // Store the block
      await _storage.put(storageKey, block);

      // Update routing table with key information
      final targetPeerId = PeerId(value: key.bytes);
      await handleRoutingTableUpdate(V_PeerInfo()..peerId = targetPeerId.value);
    } catch (e) {
      print('Error putting value: $e');
    }
  }

  /// Retrieves a value from the DHT network by its key.
  @override
  Future<Value> getValue(Key key) async {
    try {
      final storageKey = '/dht/values/${key.toString()}';
      final block = await _storage.get(storageKey);
      if (block != null) {
        return Value(block.data);
      }
      throw Exception('Value not found');
    } catch (e) {
      print('Error getting value: $e');
      rethrow;
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
              'Failed to extract CID from public resolver response.',
            );
          }
        } else {
          throw Exception(
            'Public resolver returned status code ${response.statusCode}',
          );
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

    // Parse private key for signing
    final privateKey = IPFSPrivateKey.fromString(keyPair.privateKey);

    if (!isValidCID(cid)) {
      throw ArgumentError('Invalid CID: $cid');
    }

    try {
      // Create IPNS Entry
      final valuePath = utf8.encode('/ipfs/$cid');

      // Validity: RFC3339 format, 24 hours from now
      final validityDate = DateTime.now().add(Duration(hours: 24)).toUtc();
      final validity = utf8.encode(validityDate.toIso8601String());
      final validityType = IpnsEntry_ValidityType.EOL;

      // Sequence: fetch existing record and increment
      var sequence = Int64(0);
      try {
        final existingValue = await getValue(Key.fromString(keyPair.publicKey));
        final existingEntry = IpnsEntry.fromBuffer(existingValue.bytes);
        sequence = existingEntry.sequence + 1;
      } catch (e) {
        // Record doesn't exist yet, start with sequence 0 (or 1 depending on preference, using 0 as base)
        sequence = Int64(1);
      }

      final ttl = Int64(3600); // 1 hour

      // Create data to sign (V1: value + validity + validityTypeString)
      // ValidityType is 'EOL' for EOL type.
      final dataToSign = BytesBuilder();
      dataToSign.add(valuePath);
      dataToSign.add(validity);
      dataToSign.add(utf8.encode('EOL'));

      final signature = privateKey.sign(dataToSign.toBytes());

      final entry = IpnsEntry()
        ..value = valuePath
        ..validity = validity
        ..validityType = validityType
        ..sequence = sequence
        ..ttl = ttl
        ..signature = signature;
      // ..pubKey = ... (Include public key if PeerID is hashed)

      // Serialize entry
      final entryBytes = entry.writeToBuffer();

      await putValue(Key.fromString(keyPair.publicKey), Value(entryBytes));

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
    final match = RegExp(
      r'Qm[1-9A-HJ-NP-Za-km-z]{44}',
    ).firstMatch(responseBody);
    return match?.group(0);
  }

  P2plibRouter get router => _router;

  @override
  Future<List<V_PeerInfo>> findPeer(PeerId id) async {
    try {
      final peer = await dhtClient.findPeer(id);
      if (peer != null) {
        return [V_PeerInfo()..peerId = peer.value];
      }
      return [];
    } catch (e) {
      print('Error finding peer: $e');
      return [];
    }
  }

  @override
  Future<void> provide(CID cid) async {
    try {
      await dhtClient.addProvider(cid.toString(), _router.peerId.toString());
    } catch (e) {
      print('Error providing CID: $e');
    }
  }

  /// Handles routing table updates when peer information changes
  @override
  Future<void> handleRoutingTableUpdate(V_PeerInfo peer) async {
    try {
      // updatePeer should return Future<void> to handle async operations
      await dhtClient.kademliaRoutingTable.updatePeer(peer);

      print('Updated routing table entry for peer: ${peer.peerId}');
    } catch (e) {
      print('Error updating routing table: $e');
      rethrow; // Propagate error to allow caller to handle it
    }
  }

  /// Handles requests from peers to provide content
  @override
  Future<void> handleProvideRequest(CID cid, PeerId provider) async {
    try {
      await dhtClient.addProvider(cid.toString(), provider.toString());
      print('Added provider ${provider.toString()} for CID ${cid.toString()}');
    } catch (e) {
      print('Error handling provide request: $e');
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
          'Resolved DNSLink using resolver for domain $domainName: $resolvedCid',
        );
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

  Future<Map<String, dynamic>> getStatus() async {
    return {
      'active_queries': _activeQueries.length,
      'routing_table_size': dhtClient.kademliaRoutingTable.peerCount,
      'total_providers': _providers.length,
      'protocol_version': _protocolVersion,
    };
  }
}
