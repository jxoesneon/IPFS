// lib/src/core/ipfs_node/dht_handler.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '/../src/protocols/dht/dht_client.dart';
import 'package:p2plib/p2plib.dart' as p2p;

/// Handles DHT operations for an IPFS node.
class DHTHandler {
  final DHTClient _dhtClient;

  DHTHandler(config) : _dhtClient = DHTClient(config);

  /// Starts the DHT client.
  Future<void> start() async {
    try {
      await _dhtClient.start();
      print('DHT client started.');
    } catch (e) {
      print('Error starting DHT client: $e');
    }
  }

  /// Stops the DHT client.
  Future<void> stop() async {
    try {
      await _dhtClient.stop();
      print('DHT client stopped.');
    } catch (e) {
      print('Error stopping DHT client: $e');
    }
  }

  /// Finds providers for a given CID in the DHT network.
  Future<List<p2p.Peer>> findProviders(String cid) async {
    try {
      final providers = await _dhtClient.findProviders(cid);
      print('Found providers for CID $cid: ${providers.length}');
      return providers;
    } catch (e) {
      print('Error finding providers for CID $cid: $e');
      return [];
    }
  }

  /// Publishes a value to the DHT network under a given key.
  Future<void> putValue(String key, String value) async {
    try {
      await _dhtClient.putValue(key, value);
      print('Published value under key $key.');
    } catch (e) {
      print('Error publishing value under key $key: $e');
    }
  }

  /// Retrieves a value from the DHT network by its key.
  Future<String?> getValue(String key) async {
    try {
      final value = await _dhtClient.getValue(key);
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

    return resolvedCid!;
  }

  /// Publishes an IPNS record.
  Future<void> publishIPNS(String cid, {required String keyName}) async {
    // Assuming Keystore.getKeyPair() is implemented
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
    final match = RegExp(r'Qm[1-9A-HJ-NP-Za-km-z]{44}').firstMatch(responseBody);
    return match?.group(0);
  }
}
