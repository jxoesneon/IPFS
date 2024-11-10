import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;
import '../dht_client.dart';
import 'value_store.dart';

class ReplicationManager {
  final DHTClient _dhtClient;
  final ValueStore _valueStore;

  static const int MIN_REPLICAS = 3;
  static const Duration RECHECK_INTERVAL = Duration(hours: 1);

  ReplicationManager(this._dhtClient, this._valueStore);

  Future<void> ensureReplication(String key, Uint8List value) async {
    await _valueStore.store(key, value);

    final targetPeerId = p2p.PeerId(value: Uint8List.fromList(key.codeUnits));
    final storedReplicas = await _checkReplicas(key);

    if (storedReplicas < MIN_REPLICAS) {
      final peersNeeded = MIN_REPLICAS - storedReplicas;
      final additionalPeers = _dhtClient.kademliaRoutingTable
          .findClosestPeers(targetPeerId, peersNeeded);

      for (final peer in additionalPeers) {
        try {
          final success = await _dhtClient.storeValue(
            peer,
            Uint8List.fromList(key.codeUnits),
            value,
          );

          if (success) {
            await _valueStore.incrementReplicationCount(key);
          }
        } catch (e) {
          print('Failed to create replica on peer ${peer.toString()}: $e');
        }
      }
    }
  }

  Future<int> _checkReplicas(String key) async {
    final localValue = await _valueStore.retrieve(key);
    int replicaCount = localValue != null ? 1 : 0;

    final targetPeerId = p2p.PeerId(value: Uint8List.fromList(key.codeUnits));
    final potentialHolders =
        _dhtClient.kademliaRoutingTable.findClosestPeers(targetPeerId, 20);

    for (final peer in potentialHolders) {
      try {
        final hasValue = await _dhtClient.checkValue(peer, key);
        if (hasValue) replicaCount++;
      } catch (e) {
        continue;
      }
    }

    if (localValue != null) {
      await _valueStore.updateReplicationCount(key, replicaCount);
    }

    return replicaCount;
  }

  void startPeriodicReplicationCheck() {
    Future.doWhile(() async {
      final keys = await _valueStore.getAllKeys();
      for (final key in keys) {
        final value = await _valueStore.retrieve(key);
        if (value != null) {
          await ensureReplication(key, value);
        }
      }
      await Future.delayed(RECHECK_INTERVAL);
      return true;
    });
  }
}
