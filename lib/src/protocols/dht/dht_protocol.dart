import 'dart:async';
import 'package:dart_ipfs/src/core/peer/peer_id.dart';
import 'package:dart_ipfs/src/core/routing/routing_table.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart';

/// Implementation of the Kademlia DHT protocol following IPFS specs
class DHTProtocol {
  static const String PROTOCOL_ID = '/ipfs/kad/1.0.0';
  static const int ALPHA = 3; // Number of parallel lookups
  static const int K = 20; // Size of k-buckets

  final RoutingTable _routingTable;
  final PeerStore _peerStore;
  final NetworkHandler _network;

  DHTProtocol({
    required RoutingTable routingTable,
    required PeerStore peerStore,
    required NetworkHandler network,
  })  : _routingTable = routingTable,
        _peerStore = peerStore,
        _network = network;

  /// Finds the closest peers to a given key
  Future<List<PeerId>> findClosestPeers(List<int> key,
      {int numPeers = K}) async {
    final closest = _routingTable.getNearestPeers(key, numPeers);
    final results = <PeerId>[];

    // Parallel lookups following Kademlia spec
    final futures = <Future>[];
    for (var i = 0; i < ALPHA && i < closest.length; i++) {
      futures.add(_queryPeer(closest[i], key));
    }

    await Future.wait(futures);
    return results;
  }

  /// Handles an incoming FindNode request
  Future<FindNodeResponse> handleFindNode(FindNodeRequest request) async {
    final targetKey = request.key;
    final closestPeers = _routingTable.getNearestPeers(targetKey, K);

    return FindNodeResponse()
      ..closerPeers.addAll(closestPeers.map((p) => p.toDHTPeer()));
  }

  // Other DHT protocol methods...
}
