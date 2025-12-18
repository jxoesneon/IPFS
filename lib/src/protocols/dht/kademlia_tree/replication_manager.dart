import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;
import '../dht_client.dart';
import 'value_store.dart';

/// Manages value replication across the DHT network.
///
/// Ensures minimum replica count and periodically checks
/// replica health across the network.
class ReplicationManager {
  /// Creates a manager with [_dhtClient] and [_valueStore].
  ReplicationManager(this._dhtClient, this._valueStore);
  final DHTClient _dhtClient;
  final ValueStore _valueStore;

  /// Minimum number of replicas to maintain.
  static const int minReplicas = 3;

  /// Interval between replication checks.
  static const Duration recheckInterval = Duration(hours: 1);

  /// Ensures minimum replicas exist for a key-value pair.
  Future<void> ensureReplication(String key, Uint8List value) async {
    await _valueStore.store(key, value);

    final targetPeerId = p2p.PeerId(value: Uint8List.fromList(key.codeUnits));
    final storedReplicas = await _checkReplicas(key);

    if (storedReplicas < minReplicas) {
      final peersNeeded = minReplicas - storedReplicas;
      final additionalPeers = _dhtClient.kademliaRoutingTable.findClosestPeers(
        targetPeerId,
        peersNeeded,
      );

      for (final _ in additionalPeers) {
        try {
          final success = await _dhtClient.storeValue(
            Uint8List.fromList(key.codeUnits),
            value,
          );

          if (success) {
            await _valueStore.incrementReplicationCount(key);
          }
        } catch (e) {
          // print('Failed to create replica on peer ${peer.toString()}: $e');
        }
      }
    }
  }

  Future<int> _checkReplicas(String key) async {
    final localValue = await _valueStore.retrieve(key);
    int replicaCount = localValue != null ? 1 : 0;

    final targetPeerId = p2p.PeerId(value: Uint8List.fromList(key.codeUnits));
    final potentialHolders = _dhtClient.kademliaRoutingTable.findClosestPeers(
      targetPeerId,
      20,
    );

    final keyBytes = Uint8List.fromList(key.codeUnits);
    for (final peer in potentialHolders) {
      final hasValue = await _dhtClient.checkValueOnPeer(peer, keyBytes);
      if (hasValue) {
        replicaCount++;
      }
    }

    if (localValue != null) {
      await _valueStore.updateReplicationCount(key, replicaCount);
    }

    return replicaCount;
  }

  /// Starts periodic background replication checks.
  void startPeriodicReplicationCheck() {
    Future.doWhile(() async {
      final keys = await _valueStore.getAllKeys();
      for (final key in keys) {
        final value = await _valueStore.retrieve(key);
        if (value != null) {
          await ensureReplication(key, value);
        }
      }
      await Future<void>.delayed(recheckInterval);
      return true;
    });
  }
}
