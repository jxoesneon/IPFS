import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;
import '../dht_client.dart';

/// Stores and replicates values across the DHT.
///
/// Handles value persistence, expiry, and replication to
/// maintain availability across the network.
class ValueStore {
  /// Number of nodes to replicate values to.
  static const int REPLICATION_FACTOR = 3;

  /// How long before values expire.
  static const Duration VALUE_EXPIRY = Duration(hours: 24);

  final Map<String, StoredValue> _values = {};
  final DHTClient _dhtClient;

  /// Creates a value store with the given [_dhtClient].
  ValueStore(this._dhtClient);

  Future<void> store(String key, Uint8List value) async {
    final storedValue = StoredValue(
      value: value,
      timestamp: DateTime.now(),
      replicationCount: 0,
    );
    _values[key] = storedValue;

    // Trigger replication
    await _replicateValue(key, value);
  }

  Future<Uint8List?> retrieve(String key) async {
    final storedValue = _values[key];
    if (storedValue == null) {
      return null;
    }

    // Check if value has expired
    if (DateTime.now().difference(storedValue.timestamp) > VALUE_EXPIRY) {
      _values.remove(key);
      return null;
    }

    return storedValue.value;
  }

  Future<void> _replicateValue(String key, Uint8List value) async {
    final targetPeerId = p2p.PeerId(value: Uint8List.fromList(key.codeUnits));
    final closestPeers = _dhtClient.kademliaRoutingTable
        .findClosestPeers(targetPeerId, REPLICATION_FACTOR);

    int successfulReplications = 0;
    for (final peer in closestPeers) {
      try {
        /*
        final success = await _dhtClient.storeValue(
            peer, Uint8List.fromList(key.codeUnits), value);

        if (success) {
          successfulReplications++;
          _values[key]?.replicationCount = successfulReplications;
        }
        */
      } catch (e) {
        print('Failed to replicate value to peer ${peer.toString()}: $e');
      }
    }

    // Verify minimum replication factor
    if (successfulReplications < REPLICATION_FACTOR ~/ 2) {
      print(
          'Warning: Failed to achieve minimum replication factor for key $key');
    }
  }

  Future<void> republishValues() async {
    final expiredValues = <String>[];

    for (final entry in _values.entries) {
      if (DateTime.now().difference(entry.value.timestamp) > VALUE_EXPIRY) {
        expiredValues.add(entry.key);
        continue;
      }

      await _replicateValue(entry.key, entry.value.value);
    }

    // Remove expired values
    for (final key in expiredValues) {
      _values.remove(key);
    }
  }

  Future<void> incrementReplicationCount(String key) async {
    final value = _values[key];
    if (value != null) {
      value.replicationCount++;
    }
  }

  Future<void> updateReplicationCount(String key, int count) async {
    final value = _values[key];
    if (value != null) {
      value.replicationCount = count;
    }
  }

  Future<List<String>> getAllKeys() async {
    // Remove expired values before returning keys
    final now = DateTime.now();
    _values.removeWhere(
        (key, value) => now.difference(value.timestamp) > VALUE_EXPIRY);

    return _values.keys.toList();
  }
}

class StoredValue {
  final Uint8List value;
  final DateTime timestamp;
  int replicationCount;

  StoredValue({
    required this.value,
    required this.timestamp,
    this.replicationCount = 0,
  });
}
