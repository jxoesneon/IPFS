import 'dart:typed_data';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import '../dht_client.dart';

/// Stores and replicates values across the DHT.
///
/// Handles value persistence, expiry, and replication to
/// maintain availability across the network.
class ValueStore {
  /// Creates a value store with the given [_dhtClient].
  ValueStore(this._dhtClient, {this.valueExpiry = const Duration(hours: 24)});

  /// Number of nodes to replicate values to.
  static const int replicationFactor = 3;

  /// How long before values expire.
  final Duration valueExpiry;

  final Map<String, StoredValue> _values = {};
  final DHTClient _dhtClient;

  /// Stores a value in the DHT with replication.
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

  /// Retrieves a value by key, returning null if expired or not found.
  Future<Uint8List?> retrieve(String key) async {
    final storedValue = _values[key];
    if (storedValue == null) {
      return null;
    }

    // Check if value has expired
    if (DateTime.now().difference(storedValue.timestamp) > valueExpiry) {
      _values.remove(key);
      return null;
    }

    return storedValue.value;
  }

  Future<void> _replicateValue(String key, Uint8List value) async {
    final targetPeerId = PeerId(value: Uint8List.fromList(key.codeUnits));
    final closestPeers = _dhtClient.kademliaRoutingTable.findClosestPeers(
      targetPeerId,
      replicationFactor,
    );

    int successfulReplications = 0;
    for (final peer in closestPeers) {
      try {
        final success = await _dhtClient.storeValueToPeer(
          peer,
          Uint8List.fromList(key.codeUnits),
          value,
        );

        if (success) {
          successfulReplications++;
          _values[key]?.replicationCount = successfulReplications;
        }
      } catch (e) {
        // Failed to replicate
      }
    }
  }

  /// Republishes all non-expired values to maintain replication.
  Future<void> republishValues() async {
    final expiredValues = <String>[];

    for (final entry in _values.entries) {
      if (DateTime.now().difference(entry.value.timestamp) > valueExpiry) {
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

  /// Increments the replication count for a key.
  Future<void> incrementReplicationCount(String key) async {
    final value = _values[key];
    if (value != null) {
      value.replicationCount++;
    }
  }

  /// Sets the replication count for a key.
  Future<void> updateReplicationCount(String key, int count) async {
    final value = _values[key];
    if (value != null) {
      value.replicationCount = count;
    }
  }

  /// Returns all non-expired keys in the store.
  Future<List<String>> getAllKeys() async {
    // Remove expired values before returning keys
    final now = DateTime.now();
    _values.removeWhere(
      (key, value) => now.difference(value.timestamp) > valueExpiry,
    );

    return _values.keys.toList();
  }
}

/// A value stored in the DHT with metadata.
class StoredValue {
  /// Creates a stored value.
  StoredValue({
    required this.value,
    required this.timestamp,
    this.replicationCount = 0,
  });

  /// The stored data.
  final Uint8List value;

  /// When the value was stored.
  final DateTime timestamp;

  /// Number of successful replications.
  int replicationCount;
}

