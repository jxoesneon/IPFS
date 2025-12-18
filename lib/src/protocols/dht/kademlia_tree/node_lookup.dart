import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:p2plib/p2plib.dart' as p2p;

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
  Future<List<p2p.PeerId>> nodeLookup(p2p.PeerId target) async {
    int iterations = 0;

    Set<p2p.PeerId> queriedPeers = {};
    List<p2p.PeerId> closestPeers = findClosestPeers(target, K);

    while (iterations++ < maxIterations) {
      List<p2p.PeerId> peersToQuery = closestPeers
          .where((p) => !queriedPeers.contains(p))
          .take(alpha)
          .toList();

      if (peersToQuery.isEmpty) break;

      List<p2p.PeerId> newClosestPeers = [];
      for (var peerId in peersToQuery) {
        try {
          List<p2p.PeerId> queriedPeers = await findNode(
            dhtClient,
            peerId,
            target,
          );
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
