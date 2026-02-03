import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';

import 'helpers.dart';

/// Extension for iterative node lookup in Kademlia DHT.
extension NodeLookup on KademliaTree {
  /// Concurrent query parallelism.
  static const int alpha = 3;

  /// Maximum lookup iterations.
  static const int maxIterations = 20;

  /// Number of closest peers to track.
  static const int K = 20;

  /// Performs iterative node lookup for [target].
  Future<List<PeerId>> nodeLookup(PeerId target) async {
    int iterations = 0;

    Set<PeerId> queriedPeers = {};
    List<PeerId> closestPeers = findClosestPeers(target, K);

    while (iterations++ < maxIterations) {
      List<PeerId> peersToQuery = closestPeers
          .where((p) => !queriedPeers.contains(p))
          .take(alpha)
          .toList();

      if (peersToQuery.isEmpty) break;

      List<PeerId> newClosestPeers = [];
      for (var peerId in peersToQuery) {
        try {
          List<PeerId> queriedPeers = await findNode(dhtClient, peerId, target);
          newClosestPeers.addAll(queriedPeers);
        } catch (e) {
          // print('Error querying peer $peerId: $e');
        }
      }

      newClosestPeers.sort(
        (a, b) => calculateDistance(
          target,
          a,
        ).compareTo(calculateDistance(target, b)),
      );
      newClosestPeers = newClosestPeers.take(K).toList();

      if (newClosestPeers.equals(closestPeers) ||
          newClosestPeers.contains(target)) {
        break;
      }

      closestPeers = newClosestPeers;
    }

    return closestPeers;
  }
}

